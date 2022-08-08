//
//  BluetoothPeripheral
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import CoreBluetooth
import Foundation
import Logging
import os.log

extension BluetoothManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            Self.logger.info("[CBManager]: is powered on", metadata: .bluetooth)
            break
        case .poweredOff:
            Self.logger.info("[CBManager]: is not powered on", metadata: .bluetooth)
            break
        case .resetting:
            Self.logger.info("[CBManager]: is resetting", metadata: .bluetooth)
            break
        case .unauthorized:
            if #available(iOS 13.0, *) {
                switch central.authorization {
                case .denied:
                    Self.logger.info(
                        "[CBManager]: You are not authorised to use Bluetooth",
                        metadata: .bluetooth
                    )
                case .restricted:
                    Self.logger.info("[CBManager]: Bluetooth is restricted", metadata: .bluetooth)
                default:
                    Self.logger.info("[CBManager]: Unexpected authorisation", metadata: .bluetooth)
                }
            }
            else {
                Self.logger.info("[CBManager]: Unknown status", metadata: .bluetooth)
            }
            break
        case .unknown:
            Self.logger.info("[CBManager]: state is unknown", metadata: .bluetooth)
            break
        case .unsupported:
            Self.logger.info(
                "[CBManager]: Bluetooth is not supported on this device",
                metadata: .bluetooth
            )
            break
        @unknown default:
            Self.logger.info(
                "[CBManager]: A previously unknown central manager state occurred",
                metadata: .bluetooth
            )
            break
        }

        if central.state == .poweredOn {
            self.connectableState = .Created
        }
        else {
            self.connectableState = .Unknown
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard let macAddress = self.macAddress else {
            return Self.logger.info("MAC address not set, skipping", metadata: .bluetooth)
        }

        Self.logger.info("Peripheral found", metadata: .bluetooth)

        guard let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String else {
            return Self.logger.info("Couldn't find peripheral's name, skipping", metadata: .bluetooth)
        }

        let nameComponents = name.components(separatedBy: BluetoothConstants.DeviceNameSeparator)
        guard let first = nameComponents.first, first == BluetoothConstants.DeviceNamePrefix else {
            return Self.logger.info(
                "Name \(name) does not conforms to protocol, skipping",
                metadata: .bluetooth
            )
        }

        guard let last = nameComponents.last else {
            return Self.logger.info("MAC address not found", metadata: .bluetooth)
        }

        guard last == macAddress else {
            return Self.logger.info(
                "MAC address \"\(last)\" doesn't match with \"\(macAddress)\", skipping",
                metadata: .bluetooth
            )
        }

        Self.logger.info(
            "Peripheral found \(peripheral.identifier.uuidString), stopping scan",
            metadata: .bluetooth
        )
        self.centralManager.stopScan()

        self.discoveredPeripheral = peripheral

        Self.logger.info("Connecting to peripheral", metadata: .bluetooth)
        self.centralManager.connect(peripheral)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Self.logger.info(
            "Connected with peripheral \(peripheral.description), discovering services",
            metadata: .bluetooth
        )

        peripheral.delegate = self
        peripheral.discoverServices([CBUUID(string: BluetoothConstants.GattService)])
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Self.logger.info("Disconnected from peripheral \(peripheral.description)", metadata: .bluetooth)

        self.connectableState = .Unknown
    }
}
