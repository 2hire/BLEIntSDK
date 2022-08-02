import Foundation

public enum BLEIntSDKError: Error {
    public typealias RawValue = String
    case InvalidData
    case InvalidState
    case InvalidSession
    case NotConnected
    case Timeout
    case Internal
    case PeripheralNotFound

    public var rawValue: RawValue {
        switch self {
        case .InvalidData: return "invalid_data"
        case .InvalidState: return "invalid_state"
        case .InvalidSession: return "invalid_session"
        case .NotConnected: return "not_connected"
        case .Timeout: return "timeout"
        case .PeripheralNotFound: return "peripheral_not_found"
        case .Internal: return "internal"
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "invalid_data": self = .InvalidData
        case "invalid_state": self = .InvalidState
        case "invalid_session": self = .InvalidSession
        case "not_connected": self = .NotConnected
        case "timeout": self = .Timeout
        case "peripheral_not_found": self = .PeripheralNotFound
        case "internal": self = .Internal
        default: return nil
        }
    }

    public var errorDescription: String? {
        switch self {
        case .InvalidData: return ClientError.InvalidData.errorDescription
        case .InvalidState: return ClientError.InvalidState.errorDescription
        case .InvalidSession: return ClientError.InvalidSession.errorDescription
        case .NotConnected: return BluetoothError.NotConnected.errorDescription
        case .Timeout: return BluetoothError.Timeout.errorDescription
        case .PeripheralNotFound: return BluetoothError.PeripheralNotFound.errorDescription
        case .Internal: return NSLocalizedString("Internal Error", comment: "")
        }
    }

    internal static func from(error: Error) -> Self {
        switch error {
        case ClientError.InvalidData: return .InvalidData
        case ClientError.InvalidState: return .InvalidState
        case ClientError.InvalidSession: return .InvalidSession
        case BluetoothError.NotConnected: return .NotConnected
        case BluetoothError.Timeout: return .Timeout
        case BluetoothError.PeripheralNotFound: return .PeripheralNotFound
        default: return .Internal
        }
    }
}
