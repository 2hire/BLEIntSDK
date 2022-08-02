//
//  ClientError
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation

public enum ClientError: Error {
    private static let InvalidSessionStateFlow: [[WritableTLState]] = [
        [.Writing, .Connected, .Unknown, .Errored], [.Reading, .Unknown, .Errored],
    ]

    case InvalidData
    case InvalidState
    case InvalidSession

    static func checkInvalidSession(for states: [WritableTLState]) -> Bool {
        return Self.InvalidSessionStateFlow.first { states.suffix($0.count) == $0 } != nil
    }
}

extension ClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .InvalidData:
            return NSLocalizedString("Client invalid data received", comment: "")
        case .InvalidState:
            return NSLocalizedString("Client invalid state", comment: "")
        case .InvalidSession:
            return NSLocalizedString("Client invalid session", comment: "")
        }
    }
}
