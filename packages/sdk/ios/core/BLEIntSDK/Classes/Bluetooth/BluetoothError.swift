//
//  BluetoothError
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation

internal enum BluetoothError: Error {
    case Generic
    case NotConnected
    case NotReading
    case PeripheralNotFound
    case CharacteristicNotFound
    case ApiMisuse
    case Timeout
}

extension BluetoothError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ApiMisuse:
            return NSLocalizedString("Bluetooth Api misuse, an action is already running", comment: "")
        case .NotConnected:
            return NSLocalizedString("Bluetooth is not in connected state", comment: "")
        case .NotReading:
            return NSLocalizedString("Bluetooth is not in Reading state", comment: "")
        case .Timeout:
            return NSLocalizedString("Bluetooth action timeout error", comment: "")
        case .CharacteristicNotFound:
            return NSLocalizedString("Bluetooth characteristic not found", comment: "")
        case .PeripheralNotFound:
            return NSLocalizedString("Bluetooth peripheral not found", comment: "")
        case .Generic:
            return NSLocalizedString("Bluetooth generic error", comment: "")
        }
    }
}
