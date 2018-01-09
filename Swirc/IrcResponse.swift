/**
 IrcResponse.swift

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

/// This is a non-complete list of response codes found in responses from the server
enum IrcResponseCode: String {
    // Non-numeric respones codes
    case Notice = "NOTICE"
    case Mode = "MODE"
    case Join = "JOIN"
    case Part = "PART"
    case PrivateMessage = "PRIVMSG"
    
    // Client-server connection info only
    case Welcome = "001"
    case YourHost = "002"
    case Created = "003"
    case MyInfo = "004"
    case Bounce = "005"

    // Server info
    case StatsUpTime = "242"
    case StatsOnline = "243"
    case UserModeIs = "221"
    case ServerList = "234"
    case ServerListEnd = "235"
    case LUserClient = "251"
    case LUserOp = "252"
    case LUserUnknown = "253"
    case LUserChannels = "254"
    case LUserMe = "255"

    // Generated in response to commands
    case UserHost = "302"
    case ISON = "303"
    case Away = "301"
    case UnAway = "305"
    case NowAway = "306"

    // Who is-related responses
    case WhoIsUser = "311"
    case WhoIsServer = "312"
    case WhoIsOperator = "313"
    case WhoIsIdle = "317"
    case EndOfWhoIs = "318"
    case WhoIsChannels = "319"

    // Who was
    case WhoWasUser = "314"
    case EndOfWhoWas = "369"

    case List = "322"
    case ListEnd = "323"

    case UNIQOPIS = "325"

    case ChannelModeIs = "324"
    case NoTopic = "331"
    case Topic = "332"

    case Inviting = "341"
    case Summoning = "342"
    case InviteList = "346"
    case EndOfInviteList = "347"
    case ExceptList = "348"
    case EndOfExceptList = "349"

    case Version = "351"

    case WhoReply = "352"
    case EndOfWho = "315"

    case NameReply = "353"
    case EndOfNames = "366"

    case Links = "364"
    case EndOfLinks = "365"

    case BanList = "367"
    case EndOfBanList = "368"

    case Info = "371"
    case EndOfInfo = "374"

    case MOTDStart = "375"
    case MOTD = "372"
    case EndOfMOTD = "376"

    case YoureOperator = "381"
    case YoureService = "383"

    case Time = "391"

    /* OTHERS */

    // Errors
    case NoSuchNick = "401"
    case NoSuchServer = "402"
    case NoSuchChannel = "403"
    case CannotSendToChannel = "404"
    case TooManyChannels = "405"
    case WasNoSuchNick = "406"
    case TooManyTargets = "407"
    case NoSuchService = "408"
    case NoOrigin = "409"
    case NoRecipient = "411"
    case NoTextToSend = "412"
    case NoTopLevel = "413"
    case WildTopLevel = "414"
    case BadMask = "415"

    case UnknownCommand = "421"
    case NoMOTD = "422"
    case NoNicknameGiven = "431"
    case ErroneusNickname = "432"
    case NicknameInUse = "433"
    case NickCollision = "436"
    case UnavailableResource = "437"
    case UserNotInChannel = "441"
    case NotOnChannel = "442"
    case UserOnChannel = "443"
    case NoLogin = "444"
    case NotRegistered = "451"
    case NeedMoreParams = "461"
    case AlreadyRegistered = "462"
    case PasswordMismatch = "464"

    case YoureBannedCreep = "465"
    case KeySet = "467"
    case ChannelIsFull = "471"
    case UnknownMode = "472"
    case InviteOnlyChannel = "473"
    case BannedFromChannel = "474"
    case BadChannelKey = "475"
    case NoChannelModes = "476"
    case NoPrivileges = "481"
    case UserModeUnknownFlag = "501"
    case UsersDontMatch = "502"
}
