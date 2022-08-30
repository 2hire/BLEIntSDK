//
//  ProtocolConstants
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation

internal let ProtocolVersion: UInt8 = 0x01

internal enum ProtocolFrame {
    static let SessionStart: [UInt8] = [0xC1, 0xA0, 0xC1, 0xA0]
    static let SessionEnd: [UInt8] = [0xE2, 0x1B, 0xE7, 0x7A]

    static let CommandStart: [UInt8] = [0xE2, 0x2A, 0xDA, 0xDA]
    static let CommandEnd: [UInt8] = [0xE2, 0x1B, 0xE7, 0x7A]
}

internal enum CommandIdentifier: UInt8 {
    case Ack = 0xF0
    case Nack = 0xF1
    case Error = 0xF2
}

internal enum ProtocolPacketType: UInt8 {
    case Request = 0xAA
    case Response = 0x55
}

internal enum ProtocolErrorCode: UInt8 {
    case AlreadyValidated = 0x01
    case InvalidAccess = 0xFF
    case InvalidTimestamp = 0xFE
    case InvalidTag = 0xFD
    case InvalidCounter = 0xFC
    case InvalidCmd = 0xFB
    case InvalidStartByte = 0xFA
    case UnknownVersion = 0xF9
    case InvalidCmdTag = 0xF8
    case InvalidLength = 0xF7
}
