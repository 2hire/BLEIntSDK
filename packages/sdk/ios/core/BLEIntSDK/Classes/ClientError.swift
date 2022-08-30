//
//  ClientError
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation

public enum ClientError: Error {
    case InvalidData
    case InvalidState
    case InvalidSession(errorCode: String)
    case InvalidCommand(errorCode: String)
}

extension ClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .InvalidData:
            return NSLocalizedString("Client invalid data received", comment: "")
        case .InvalidState:
            return NSLocalizedString("Client invalid state", comment: "")
        case .InvalidSession(let errorCode):
            return NSLocalizedString("Client invalid session (\(errorCode))", comment: "")
        case .InvalidCommand(let errorCode):
            return NSLocalizedString("Client invalid command (\(errorCode))", comment: "")
        }
    }
}
