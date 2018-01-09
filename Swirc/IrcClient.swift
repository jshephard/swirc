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

/// Manages the connection to the IRC server
public class IrcClient: NSObject, GCDAsyncSocketDelegate {
    
    var hostname: String
    var port: UInt16 = 6667
    var user: IrcUser
    var connectedChannels = [String: IrcChannel]()
    var connected: Bool = false

    // Authenticated here means a valid nickname and password
    var authenticated: Bool = false
    
    var socket: GCDAsyncSocket

    var interimSocketData: String?
    
    /// Initialize IrcClient
    ///
    /// - Parameters:
    ///   - hostname: Hostname of the IRC server. This may include the port number.
    ///   - user: An IrcUser, which contains relevant information for authentication.
    /// - Throws: ConnectionError.invalidHostname
    public init(hostname: String, user: IrcUser) throws {
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

        super.init()
        
        // Set the delegate and delegate queue after super.init
        self.socket.setDelegate(self, delegateQueue: DispatchQueue.main)
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

    /// Joins the specified channel
    ///
    /// - Parameter channelString: The channel
    public func joinChannel(_ channelString: String) {
        // TODO: check connection and authentication status
        // TODO: validation of string
        if connectedChannels[channelString] != nil {
            // Already connected
            return
        }

        writeString("JOIN \(channelString)")
    }

    /// Parts the specified channel
    ///
    /// - Parameter channelString: The channel
    public func partChannel(_ channelString: String) {
        // TODO: check connection and authentication status
        // TODO: validation of string

        writeString("PART \(channelString)")
    }

    /* *** PRIVATE HELPERS *** */

    /// Send the authentication handshake
    func sendAuthentication() {
        let username = user.username ?? "guest"
        if let password = user.password {
            writeString("PASS \(password)")
        }
        // TODO: customizing the other attributes, i.e. invisibility, real name
        writeString("USER \(username) 8 * :guest")
        writeString("NICK \(user.nick)")
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

    /// Called when the socket receives data from the IRC server
    @objc public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        socket.readData(withTimeout: -1.0, tag: 0)

        if let str = String.init(data: data, encoding: String.Encoding.ascii) {
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
                if !command.hasPrefix(":") {
                    return // TODO: do clients ever _not_ receive :?
                }

                // TODO: strip out the following into a separate parser function
                let arguments = command.split(separator: " ")

                // Remove the ':' prefix
                let prefix = String(String(arguments[0]).dropFirst(1))

                // Extract out this information with a regex
                var nick: String? = prefix
                var user: String?
                var host: String?
                do {
                    // TODO: separate function?
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
                        nick = results[0]
                        user = results[1]
                        host = results[2]
                    }
                } catch let error {
                    // TODO: handle error better
                    print(error)
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

                #if DEBUG
                    print("""
\(nick ?? "") \(user ?? "") \(host ?? "") \(responseCode == nil ? responseCodeRaw : responseCode.debugDescription) \(params)
""")
                #endif
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

        if let data = command.data(using: .ascii) {
            socket.write(data, withTimeout: -1.0, tag:0)
        }
    }
    
}
