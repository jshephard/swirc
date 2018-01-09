/**
 IrcUser.swift

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

/// Structure for encapsulating user details, like nickname, username or password
public struct IrcUser {

    var password: String?
    public private(set) var username: String?
    public private(set) var nick: String
    
    /// Initialize the IrcUser with nick alone
    ///
    /// - Parameter nick: Nickname to use on the IRC server
    public init(nick: String) {
        self.nick = nick
    }
    
    /// Initialize the IrcUser with a nickname, username and password
    ///
    /// - Parameters:
    ///   - nick: Nickname to use on the IRC server
    ///   - username: Username for the IRC server
    ///   - password: Password for the IRC server
    public init(nick: String, username: String, password: String) {
        self.nick = nick
        self.username = username
        self.password = password
    }

}
