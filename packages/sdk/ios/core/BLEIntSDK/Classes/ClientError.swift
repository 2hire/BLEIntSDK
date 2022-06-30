//
//  ClientError
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation

public enum ClientError: Error {
    case InvalidDataError
    case InvalidState
}

extension ClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .InvalidDataError:
            return NSLocalizedString("Client invalid data received", comment: "")
        case .InvalidState:
            return NSLocalizedString("Client invalid state", comment: "")
        }
    }
}
