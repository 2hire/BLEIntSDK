//
//  BluetoothPeripheral
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import CoreBluetooth
import Foundation
import os.log

extension BluetoothManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            os_log("[CBManager]: is powered on", log: .bluetooth, type: .debug)
            break
        case .poweredOff:
            os_log("[CBManager]: is not powered on", log: .bluetooth, type: .debug)
            break
        case .resetting:
            os_log("[CBManager]: is resetting", log: .bluetooth, type: .debug)
            break
        case .unauthorized:
            if #available(iOS 13.0, *) {
                switch central.authorization {
                case .denied:
                    os_log(
                        "[CBManager]: You are not authorised to use Bluetooth",
                        log: .bluetooth,
                        type: .debug
                    )
                case .restricted:
                    os_log("[CBManager]: Bluetooth is restricted", log: .bluetooth, type: .debug)
                default:
                    os_log("[CBManager]: Unexpected authorisation", log: .bluetooth, type: .debug)
                }
            }
            else {
                os_log("[CBManager]: Unknown status", log: .bluetooth, type: .debug)
            }
            break
        case .unknown:
            os_log("[CBManager]: state is unknown", log: .bluetooth, type: .debug)
            break
        case .unsupported:
            os_log(
                "[CBManager]: Bluetooth is not supported on this device",
                log: .bluetooth,
                type: .debug
            )
            break
        @unknown default:
            os_log(
                "[CBManager]: A previously unknown central manager state occurred",
                log: .bluetooth,
                type: .debug
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
            return os_log("MAC address not set, skipping", log: .bluetooth, type: .debug)
        }

        os_log("Peripheral found", log: .bluetooth, type: .debug)

        guard let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String else {
            return os_log("Couldn't find peripheral's name, skipping", log: .bluetooth, type: .debug)
        }

        let nameComponents = name.components(separatedBy: BluetoothConstants.DeviceNameSeparator)
        guard let first = nameComponents.first, first == BluetoothConstants.DeviceNamePrefix else {
            return os_log(
                "Name %@ does not conforms to protocol, skipping",
                log: .bluetooth,
                type: .debug,
                name
            )
        }

        guard let last = nameComponents.last, last == macAddress else {
            return os_log(
                "MAC address doesn't match with %{private}@, skipping",
                log: .bluetooth,
                type: .debug,
                macAddress
            )
        }

        os_log(
            "Peripheral found %@, stopping scan",
            log: .bluetooth,
            type: .debug,
            peripheral.identifier.uuidString
        )
        self.centralManager.stopScan()

        peripheral.delegate = self
        self.discoveredPeripheral = peripheral

        os_log("Connecting to peripheral", log: .bluetooth, type: .debug)
        self.centralManager.connect(peripheral)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        os_log(
            "Connected with peripheral %@, discovering services",
            log: .bluetooth,
            type: .debug,
            peripheral.description
        )

        peripheral.discoverServices([CBUUID(string: BluetoothConstants.GattService)])
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        os_log("Disconnected from peripheral %@", log: .bluetooth, type: .debug, peripheral.description)

        self.connectableState = .Unknown
    }
}
