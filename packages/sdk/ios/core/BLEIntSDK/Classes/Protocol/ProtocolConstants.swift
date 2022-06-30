//
//  ProtocolConstants
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation

internal let ProtocolVersion: UInt8 = 0x01

internal enum ProtocolConstant {
    static let StartSequence: [UInt8] = [0xC1, 0xA0, 0xC1, 0xA0]
    static let EndSequence: [UInt8] = [0xE2, 0x1B, 0xE7, 0x7A]

    static let Ack: UInt8 = 0xF0
    static let Nack: UInt8 = 0xF1

    static let DisconnectionTimeout = 3.5
}

internal enum ProtocolMessageType: UInt8 {
    case Request = 0xAA
    case Response = 0x55
}
