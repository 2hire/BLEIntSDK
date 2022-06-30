//
//  ProtocolError.swift
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation

internal enum ProtocolError: Error {
    case Generic
    case ApiMisuse
    case InvalidData
    case Writable
    case Crypto
}
