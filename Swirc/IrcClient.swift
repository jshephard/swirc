/**
 IrcClient.swift

 MIT License
 
 Copyright 2018 James Shephard
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this
 software and associated documentation files (the "Software"), to deal in the Software
 without restriction, including without limitation the rights to use, copy, modify,
 merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be included in all copies
 or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
 OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 **/

import Foundation

import CocoaAsyncSocket
import SwiftyBeaver

/// Manages the connection to the IRC server
public class IrcClient: NSObject, GCDAsyncSocketDelegate {

    var log: SwiftyBeaver.Type

    var hostname: String
    var port: UInt16 = 6667
    var user: IrcUser
    var connectedChannels = [String: IrcChannel]()
    var connected: Bool = false

    // Authenticated here means a valid nickname and password
    var authenticated: Bool = false
    
    var socket: GCDAsyncSocket
    var interimSocketData: String?

    // Generic command handler, accepting the IrcUser (which may just be the host),
    // as well as a list of parameters
    typealias CommandHandler = (IrcUser, [String]) -> Void
    var handlers = [IrcResponseCode: CommandHandler]()
    weak var delegate: IrcClientProtocol?

    // Server information
    var motd: String?

    /// Initialize IrcClient
    ///
    /// - Parameters:
    ///   - hostname: Hostname of the IRC server. This may include the port number.
    ///   - user: An IrcUser, which contains relevant information for authentication.
    /// - Throws: ConnectionError.invalidHostname
    public convenience init(hostname: String, user: IrcUser) throws {
        try self.init(hostname: hostname, user: user, delegate: nil)
    }
    
    /// Initialize IrcClient
    ///
    /// - Parameters:
    ///   - hostname: Hostname of the IRC server. This may include the port number.
    ///   - user: An IrcUser, which contains relevant information for authentication.
    ///   - delegate: Delegate that will handle IRC events (i.e. messages received)
    /// - Throws: ConnectionError.invalidHostname
    public init(hostname: String, user: IrcUser, delegate: IrcClientProtocol?) throws {
        // Check hostname to see if it contains a port (defaults to 6667)
        if hostname.range(of: ":") != nil {
            let host = hostname.split(separator: ":")
            self.hostname = String(host[0])
            if let port = UInt16(host[1]) {
                self.port = port
            } else {
                throw ConnectionError.invalidHostname
            }
        } else {
            self.hostname = hostname
        }

        self.user = user
        self.socket = GCDAsyncSocket.init()
        self.delegate = delegate
        self.log = SwiftyBeaver.self
        let console = ConsoleDestination()
        log.addDestination(console)

        super.init()
        
        // Set the delegate and delegate queue after super.init
        self.socket.setDelegate(self, delegateQueue: DispatchQueue.main)
        self.initializeHandlers()
    }

    public func setDelegate(delegate: IrcClientProtocol) {
        self.delegate = delegate
    }

    /// Connect to the IRC server
    ///
    /// - Throws: ConnectionError.alreadyConnected, ConnectionError.invalidHostname
    public func connect() throws {
        // Don't reconnect if we are already connected
        if connected {
            throw ConnectionError.alreadyConnected
        }
        
        do {
            try socket.connect(toHost: hostname, onPort: port)
        } catch let error {
            print(error.localizedDescription)
            // TODO: when does connect() fail?
            throw ConnectionError.invalidHostname
        }
    }

    /// Update the current user (i.e. the nickname)
    ///
    /// - Parameter user: New or updated IrcUser
    public func setUser(user: IrcUser) {
        self.user = user

        if connected {
            // TODO: update user details on server. is the following sufficient?
            sendAuthentication()
        }
    }

    /// Sends a private message to the specified user
    ///
    /// - Parameters:
    ///   - target: Irc user to send message to
    ///   - message: Message content
    public func sendPrivateMessage(toUser target: IrcUser, message: String) {
        self.sendPrivateMessage(toTarget: target.nickname, message: message)
    }


    /// Sends a message to the specified channel
    ///
    /// - Parameters:
    ///   - target: Irc channel to send message to
    ///   - message: Message content
    public func sendPrivateMessage(toChannel target: IrcChannel, message: String) {
        self.sendPrivateMessage(toTarget: target.channelName, message: message)
    }

    /// Sends a message to the specified target
    ///
    /// - Parameters:
    ///   - target: Target to send message to
    ///   - message: Message content
    public func sendPrivateMessage(toTarget target: String, message: String) {
        guard connected && authenticated else {
            log.error("Attempting to message while connected = \(connected)" +
                      " and authenticated = \(authenticated)")
            return
        }

        // IF CHANNEL check connected to channel

        writeString("PRIVMSG \(target) :\(message)")
    }

    /// Joins the specified channel
    ///
    /// - Parameter channelString: The channel
    public func joinChannel(_ channelString: String) {
        guard connected && authenticated else {
            log.error("Attempting to part channel \(channelString) while connected = " +
                      "\(connected) and authenticated = \(authenticated)")
            return
        }

        // TODO: validation of string
        if connectedChannels[channelString] != nil {
            // Already connected
            log.debug("Attempting to re-join channel, skipping")
            return
        }

        writeString("JOIN \(channelString)")
    }

    /// Parts the specified channel
    ///
    /// - Parameters:
    ///   - channelString: The channel
    ///   - reason: Reason for parting (optional)
    public func partChannel(_ channelString: String, reason: String? = nil) {
        guard connected && authenticated else {
            log.error("Attempting to part channel \(channelString) while connected = " +
                      "\(connected) and authenticated = \(authenticated)")
            return
        }
        if connectedChannels[channelString] == nil {
            return
        }

        if let reason = reason {
            writeString("PART \(channelString) :\(reason)")
        } else {
            writeString("PART \(channelString)")
        }
    }

    /// Disconnects from the IRC server
    ///
    /// - Parameter reason: Reason for quitting server
    public func quit(reason: String? = nil) {
        guard connected else {
            // Not currently connected anyway!
            return
        }

        if let reason = reason {
            writeString("QUIT :\(reason)")
        } else {
            writeString("QUIT")
        }
    }

    /* *** PRIVATE HELPERS *** */

    /// Send the authentication handshake
    func sendAuthentication() {
        if !authenticated {
            let username = user.username ?? NSUserName()
            let realname = user.realname ?? NSFullUserName()
            if let password = user.password {
                writeString("PASS \(password)")
            }

            // TODO: customizing the other attributes, i.e. invisibility, real name
            writeString("USER \(username) 8 * :\(realname)")
        }

        writeString("NICK \(user.nickname)")
    }

    /* *** COMMAND HANDLERS *** */

    /// Initialize the handlers dictionary with all implemented command handlers
    func initializeHandlers() {
        handlers[IrcResponseCode.Ping] = ping
        handlers[IrcResponseCode.Welcome] = welcome
        handlers[IrcResponseCode.PrivateMessage] = privateMessage
        handlers[IrcResponseCode.MOTDStart] = newMotd
        handlers[IrcResponseCode.MOTD] = motdLine
        handlers[IrcResponseCode.EndOfMOTD] = endOfMotd
        handlers[IrcResponseCode.Join] = userJoined
        handlers[IrcResponseCode.Part] = userParted
    }

    func ping(user: IrcUser, params: [String]) {
        writeString("PONG")
    }

    func welcome(user: IrcUser, params: [String]) {
        // Response codes 001-004 sent on successful authentication
        self.authenticated = true
    }

    func userJoined(user: IrcUser, params: [String]) {
        guard params.count == 1 else {
            log.error("Incorrect number of parameters in join message")
            return
        }

        let channel = params[0]

        if self.user.nickname == user.nickname {
            // We've joined this channel, add it to our list of connected channels
            if connectedChannels[channel] == nil {
                let ircChannel = IrcChannel.init(ircClient: self, channelName: channel)
                self.connectedChannels[channel] = ircChannel

                // TODO: might move this to after end of nick handler so delegate has
                // all the nicks available
                self.delegate?.joinedChannel(channel: ircChannel)
            }
        } else {
            // Update channel user list
            if let ircChannel = connectedChannels[channel] {
                ircChannel.addUser(user: user)
                self.delegate?.userJoinedChannel(user: user, channel: ircChannel)
            }
        }
    }

    func userParted(user: IrcUser, params: [String]) {
        guard params.count >= 1 else {
            log.error("Incorrect number of parameters in join message")
            return
        }

        let channel = params[0]

        if self.user.nickname == user.nickname {
            // We've parted this channel, remove it from our list of connected channels
            if connectedChannels[channel] != nil {
                connectedChannels.removeValue(forKey: channel)
                self.delegate?.partedChannel(channel: channel)
            }
        } else {
            let reason: String? = params.count > 1 ? params[1] : nil

            // Update channel user list
            if let ircChannel = connectedChannels[channel] {
                ircChannel.removeUser(user: user)
                self.delegate?.userPartedChannel(user: user, channel: ircChannel,
                                                 reason: reason)
            }
        }
    }

    func privateMessage(user: IrcUser, params: [String]) {
        guard params.count == 2 else {
            log.error("Incorrect number of parameters in private message")
            return
        }

        let channel = params[0], message = params[1]
        // TODO: private channel message and private user message separated?
        self.delegate?.privateMessage(user: user, source: channel, message: message)
    }

    func newMotd(user: IrcUser, params: [String]) {
        guard params.count == 2 else {
            log.error("Incorrect number of parameters in MOTD start")
            return
        }
        motd = params[1]
    }

    func motdLine(user: IrcUser, params: [String]) {
        guard params.count == 2 else {
            log.error("Incorrect number of parameters in MOTD")
            return
        }

        if let motd = motd {
            self.motd = "\(motd)\n\(params[1])"
        } else {
            self.motd = params[1]
        }
    }

    func endOfMotd(user: IrcUser, params: [String]) {
        if let motd = motd {
            self.delegate?.newMOTD(motd: motd)
        }
    }

    /* !!!IN PROGRESS!!! */

    func modeUpdate(user: IrcUser, params: [String]) {
        guard params.count == 2 else {
            log.error("Incorrect number of parameters in mode update")
            return
        }

        let target = params[0]
        let modes = params[1] //e.g. +ns
    }

    func nameReply(user: IrcUser, params: [String]) {
        guard params.count >= 4 else {
            log.error("Incorrect number of parameters in name reply")
            return
        }
        let target = params[0]
        let channelStatus = params[1] // @, * or =
        let channel = params[2]
        let user = params[3] // may include @, +, etc.
    }

    func endOfNames(user: IrcUser, params: [String]) {
        guard params.count >= 2 else {
            log.error("Incorrect number of parameters in end of names")
            return
        }

        let target = params[0]
        let channel = params[1]
    }
    
    /* *** SOCKET PROTOCOL **** */

    /// Called when the socket first connects successfully to the IRC server
    @objc public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        self.connected = true

        // Begin the handshake sequence
        sendAuthentication()
        
        // Begin receiving data
        socket.readData(withTimeout: -1.0, tag: 0)
    }

    func parseCommand(_ command: String) {
        if !command.hasPrefix(":") {
            return
        }

        let arguments = command.split(separator: " ")

        // Remove the ':' prefix
        let prefix = String(String(arguments[0]).dropFirst(1))

        // Extract out this information with a regex
        var nickname: String = prefix
        var username: String?
        var hostname: String?
        do {
            let regex = try NSRegularExpression(pattern: "^([^@!]+)(?:!([^@!]+))?(?:@([^@!]+))?$", options: [])
            let matches = regex.matches(in: prefix, options: [], range: NSRange(location: 0, length: prefix.count))
            if let match = matches.first {
                var results = [String?]()
                for index in 1..<match.numberOfRanges {
                    let range = match.range(at: index)
                    if !NSEqualRanges(range, NSMakeRange(NSNotFound, 0)) {
                        results.append((prefix as NSString).substring(with: range))
                    } else {
                        results.append(nil)
                    }
                }
                nickname = results[0] ?? nickname
                username = results[1]
                hostname = results[2]
            }
        } catch let error {
            log.error("Error occurred during regex: \(error.localizedDescription)")
        }

        let responseCodeRaw = String(arguments[1])
        let rawParams = arguments[2...].map { String($0) }

        // Parse params. Initial params are delineated by spaces, latter ones
        // can have spaces in them but begin with a colon
        var params = [String]()
        var trailingParams = false
        var currentParam = ""

        // TODO: Make this a cleaner solution, regex perhaps?
        for rawParam in rawParams {
            if trailingParams {
                // We're now in the realm of the trailing params
                if rawParam.starts(with: ":") {
                    // New trailing param started
                    params.append(String(currentParam.dropFirst(1)))
                    currentParam = rawParam
                } else {
                    // Continue adding to our current trailing param
                    currentParam += " " + rawParam
                }
            } else {
                if rawParam.starts(with: ":") {
                    // This is our first trailing param
                    trailingParams = true
                    currentParam = rawParam
                } else {
                    params.append(rawParam)
                }
            }
        }
        if trailingParams {
            params.append(String(currentParam.dropFirst(1)))
        }

        let responseCode = IrcResponseCode(rawValue: responseCodeRaw)
        let commandUser = IrcUser.init(nickname: nickname, username: username,
                                       hostname: hostname)

        if let responseCode = responseCode {
            if let handler = handlers[responseCode] {
                handler(commandUser, params)
            } else {
                #if DEBUG
                    print("\(nickname) \(username ?? "") \(hostname ?? "") \(responseCode.rawValue) \(params)")
                #endif
                self.delegate?.unhandledCommand(user: commandUser,
                                                command: responseCode,
                                                params: params)
            }
        } else {
            #if DEBUG
                print("\(nickname) \(username ?? "") \(hostname ?? "") \(responseCodeRaw) \(params)")
            #endif
            self.delegate?.unknownCommand(user: commandUser,
                                          command: responseCodeRaw,
                                          params: params)
        }
    }

    /// Called when the socket receives data from the IRC server
    @objc public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        socket.readData(withTimeout: -1.0, tag: 0)

        if let str = String.init(data: data, encoding: .utf8) ??
            String.init(data: data, encoding: .ascii) {
            // Reassemble string from previous fragmented data
            let assembledString = (interimSocketData ?? "") + str
            let fragmented: Bool = !assembledString.hasSuffix("\r\n")
            if assembledString.range(of: "\r\n") != nil {
                // We have received a full, complete command and thus can toss the
                // interim data.
                interimSocketData = nil
            }

            let commands = assembledString.components(separatedBy: "\r\n")

            for (index, command) in commands.enumerated() {
                if index == (commands.count - 1) && fragmented {
                    // Data has been fragmented, wait for next packet
                    interimSocketData = command
                    return
                }

                parseCommand(command)
            }
        }
    }

    /// Helper for writing strings to the socket
    ///
    /// - Parameter string: content to send to the server
    func writeString(_ string: String) {
        #if DEBUG
            print("Sending: \(string)")
        #endif
        // Commands must end with new lines
        var command = string
        if !command.hasSuffix("\r\n") {
            command += "\r\n"
        }

        if let data = command.data(using: .utf8) {
            socket.write(data, withTimeout: -1.0, tag:0)
        }
    }
    
}
