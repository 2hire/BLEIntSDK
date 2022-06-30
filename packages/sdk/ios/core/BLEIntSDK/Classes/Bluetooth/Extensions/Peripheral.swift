//
//  Peripheral
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import CoreBluetooth
import Foundation
import os.log

extension BluetoothManager: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            return os_log(
                "Found error while discovering services: %@",
                log: .bluetooth,
                type: .error,
                error.debugDescription
            )
        }

        guard
            let service = peripheral.services?.first(where: { element in
                element.uuid.uuidString == BluetoothConstants.GattService
            })
        else {
            return
        }

        os_log("Found service, discovering characteristics", log: .bluetooth, type: .debug)
        peripheral.discoverCharacteristics(nil, for: service)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else {
            return os_log(
                "Found error while discovering characteristics: %@",
                log: .bluetooth,
                type: .error,
                error.debugDescription
            )
        }

        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid.uuidString == BluetoothConstants.WriteCharacteristic {
                os_log(
                    "Found write characteristic %{private}@",
                    log: .bluetooth,
                    type: .debug,
                    BluetoothConstants.WriteCharacteristic
                )
                self.writeCharacteristic = characteristic
            }

            if characteristic.uuid.uuidString == BluetoothConstants.ReadCharacteristic {
                os_log(
                    "Found read characteristic %{private}@",
                    log: .bluetooth,
                    type: .debug,
                    BluetoothConstants.ReadCharacteristic
                )
                self.readCharacteristic = characteristic
            }
        }
    }
}
