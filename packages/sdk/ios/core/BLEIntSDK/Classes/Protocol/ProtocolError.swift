//
//  ProtocolError.swift
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation

internal enum ProtocolError: Error {
    case Generic
    case ApiMisuse
    case InvalidData(_ description: String? = nil)
    case Writable
    case Crypto
}

extension ProtocolError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .InvalidData(let description):
            guard let description = description else {
                return NSLocalizedString("Protocol invalid data received", comment: "")
            }

            return NSLocalizedString("Protocol invalid data received \(description)", comment: "")
        case .Generic:
            return NSLocalizedString("Protocol generic error", comment: "")
        case .Crypto:
            return NSLocalizedString("Protocol crypto error", comment: "")
        case .ApiMisuse:
            return NSLocalizedString("Protocol Api misuse, an action is already running", comment: "")
        case .Writable:
            return NSLocalizedString("Protocol writable error", comment: "")
        }
    }
}
