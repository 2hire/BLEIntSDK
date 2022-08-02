//
//  Peripheral
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import CoreBluetooth
import Foundation
import Logging
import os.log

extension BluetoothManager: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            return Self.logger.error(
                "Found error while discovering services: \(error.debugDescription)",
                metadata: .bluetooth
            )
        }

        guard
            let service = peripheral.services?.first(where: { element in
                element.uuid.uuidString == BluetoothConstants.GattService
            })
        else {
            return
        }

        Self.logger.info("Found service, discovering characteristics", metadata: .bluetooth)
        peripheral.discoverCharacteristics(nil, for: service)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else {
            return Self.logger.error(
                "Found error while discovering characteristics: \(error.debugDescription)",
                metadata: .bluetooth

            )
        }

        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid.uuidString == BluetoothConstants.WriteCharacteristic {
                Self.logger.info(
                    "Found write characteristic \(BluetoothConstants.WriteCharacteristic)",
                    metadata: .bluetooth
                )
                self.writeCharacteristic = characteristic
            }

            if characteristic.uuid.uuidString == BluetoothConstants.ReadCharacteristic {
                Self.logger.info(
                    "Found read characteristic \(BluetoothConstants.ReadCharacteristic)",
                    metadata: .bluetooth
                )
                self.readCharacteristic = characteristic
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else {
            return Self.logger.error("Error while reading RSSI", metadata: .bluetooth)
        }

        Self.logger.info("RSSI value: \(RSSI.stringValue)", metadata: .bluetooth)
    }
}
