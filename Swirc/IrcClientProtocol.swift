/**
 IrcClientProtocol.swift

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

/// All relevant delegate functions for IRC are specified here, i.e. for events like
/// message received, kicked from a channel, etc.
public protocol IrcClientProtocol: class {
    func newMOTD(motd: String)
    func privateMessage(user: IrcUser, source: String, message: String)

    func joinedChannel(channel: IrcChannel)
    func partedChannel(channel: String)

    func userJoinedChannel(user: IrcUser, channel: IrcChannel)
    func userPartedChannel(user: IrcUser, channel: IrcChannel, reason: String?)

    // Following functions are for unimplemented commands
    func unhandledCommand(user: IrcUser, command: IrcResponseCode, params: [String])
    func unknownCommand(user: IrcUser, command: String, params: [String])
}

// MARK: - Base implementation of optional IrcClientProtocol methods
public extension IrcClientProtocol {
    func newMOTD(motd: String) {
        // Stub
    }

    func joinedChannel(channel: IrcChannel) {
        // Stub
    }

    func partedChannel(channel: String) {
        // Stub
    }

    func userJoinedChannel(user: IrcUser, channel: IrcChannel) {
        // Stub
    }
    
    func userPartedChannel(user: IrcUser, channel: IrcChannel, reason: String?) {
        // Stub
    }

    func unhandledCommand(user: IrcUser, command: IrcResponseCode, params: [String]) {
        // Stub
    }

    func unknownCommand(user: IrcUser, command: String, params: [String]) {
        // Stub
    }
}
