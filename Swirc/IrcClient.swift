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
    var connectedChannels = [IrcChannel]()
    var connected: Bool = false
    
    var socket: GCDAsyncSocket
    
    /// Initialize IrcClient
    ///
    /// - Parameters:
    ///   - hostname: Hostname of the IRC server. This may include the port number.
    ///   - user: An IrcUser, which contains relevant information for authentication.
    /// - Throws: ConnectionError.invalidHostname
    public init(hostname: String, user: IrcUser) throws {
        // Check hostname to see if it contains a port (defaults to 6667)
        if hostname.range(of: ":") != nil {
            let host = hostname.components(separatedBy: ":")
            self.hostname = host[0]
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

    /// Send the authentication handshake
    func sendAuthentication() {
        if let username = user.username,
           let password = user.password {
            writeString("PASS \(password)\n")
            // TODO: customizing the real name?
            writeString("USER \(username) 8 * :guest\n")
        } else {
            // TODO: customizing username and real name?
            writeString("USER guest 8 * :guest\n")
        }
        writeString("NICK \(user.nick)\n")
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
        if let str = String.init(data: data, encoding: String.Encoding.ascii) {
            //Received: :kornbluth.freenode.net 433 * testusername :Nickname is already in use.
            #if DEBUG
            print("Received: \(str)")
            #endif
        }
        
        socket.readData(withTimeout: -1.0, tag: 0)
    }

    /// Helper for writing strings to the socket
    ///
    /// - Parameter string: content to send to the server
    func writeString(_ string: String) {
        #if DEBUG
        print("Sending: \(string)")
        #endif
        if let data = string.data(using: .ascii) {
            socket.write(data, withTimeout: -1.0, tag:0)
        }
    }
    
}
