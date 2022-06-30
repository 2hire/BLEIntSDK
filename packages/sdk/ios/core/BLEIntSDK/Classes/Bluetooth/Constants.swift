//
//  Constants
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation

internal enum BluetoothConstants {
    static let DeviceNamePrefix = "2h"
    static let DeviceNameSeparator = "_"

    static let GattService = "88283254-B0DB-7992-BB47-45A75DF6C2F1"
    static let WriteCharacteristic = "92B867E8-2AA3-5D9E-C94D-F06338E6B4E8"
    static let ReadCharacteristic = "92B867E8-2AA3-5D9E-C94D-F06338E6B4F8"
    static let Mtu = 20

    static let ConnectionTimeout = 20.0
    static let StartupTimeout = 5.0
    static let WriteResponseTimeout = 20.0
    static let ReadTimeout = 60.0
}
