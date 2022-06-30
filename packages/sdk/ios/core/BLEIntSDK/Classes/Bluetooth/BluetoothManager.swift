//
//  BluetoothManager
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import CoreBluetooth
import Foundation
import os.log

internal class BluetoothManager: NSObject {
    static let shared: BluetoothManager = BluetoothManager()

    var connectableState: WritableTLState = .Unknown {
        didSet {
            if oldValue != self.connectableState {
                os_log(
                    "Status changed (%@ -> %@)",
                    log: .bluetooth,
                    type: .debug,
                    oldValue.description,
                    self.connectableState.description
                )
                self.senderConnectableState = oldValue

                self.connectableDelegate?.connection(didChangeState: self.connectableState)
            }

            if let timer = self.timer {
                os_log("Firing timer %@", log: .bluetooth, type: .debug, timer.description)
                timer.fire()
            }
        }
    }
    private var senderConnectableState: WritableTLState = .Unknown

    var timer: Timer?

    var macAddress: String?

    var centralManager: CBCentralManager!

    var discoveredPeripheral: CBPeripheral?
    var readCharacteristic: CBCharacteristic? {
        didSet {
            if self.readCharacteristic != nil && writeCharacteristic != nil {
                self.connectableState = .Connected
            }
        }
    }
    var writeCharacteristic: CBCharacteristic? {
        didSet {
            if self.readCharacteristic != nil && writeCharacteristic != nil {
                self.connectableState = .Connected
            }
        }
    }

    var writeBuffer: [UInt8] = []
    var writingChunk: ArraySlice<UInt8> = []

    var writableDelegate: WritableTLDelegate?
    var connectableDelegate: ConnectableTLDelegate?
}

// MARK: Writing section
extension BluetoothManager: WritableTL {
    func write(data: [UInt8]) throws {
        guard self.connectableState == .Connected else {
            os_log("Bluetooth is not connected", log: .bluetooth, type: .error)

            throw BluetoothError.NotConnected
        }

        guard let writeCharacteristic = self.writeCharacteristic else {
            os_log("Write characteristic not found", log: .bluetooth, type: .error)
            throw BluetoothError.CharacteristicNotFound
        }

        guard let peripheral = self.discoveredPeripheral else {
            os_log("Peripheral not found", log: .bluetooth, type: .error)
            throw BluetoothError.PeripheralNotFound
        }

        self.writeBuffer = data
        self.writeChunk(peripheral, writeCharacteristic: writeCharacteristic)
    }

    private func writeChunk(
        _ peripheral: CBPeripheral,
        writeCharacteristic characteristic: CBCharacteristic
    ) {
        if self.writeBuffer.isEmpty {
            os_log(
                "Write buffer empty, current status %@, resetting to previous status %@",
                log: .bluetooth,
                type: .debug,
                self.connectableState.description,
                self.senderConnectableState.description
            )

            self.connectableState = self.senderConnectableState
            self.writableDelegate?.writable(didWrite: [], nil)

            return
        }

        self.connectableState = .Writing
        self.writingChunk =
            self.writeBuffer[...(min(self.writeBuffer.count, BluetoothConstants.Mtu) - 1)]

        self.timer = Timer.scheduledTimer(
            withTimeInterval: BluetoothConstants.WriteResponseTimeout,
            repeats: false,
            block: { _ in
                self.timer = nil

                // TODO: should we switch status to .Errored?

                self.writableDelegate?.writable(didWrite: self.writeBuffer, BluetoothError.Generic)
            }
        )

        let chunkData = Data(self.writingChunk)

        os_log(
            "Scheduled write timer %{private}@",
            log: .bluetooth,
            type: .debug,
            self.timer?.description ?? "Timer not set"
        )
        os_log("Writing chunk %{private}@", log: .bluetooth, type: .debug, chunkData.hexEncodedString)

        peripheral.writeValue(chunkData, for: characteristic, type: .withResponse)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil else {
            self.connectableState = .Errored

            return os_log(
                "Found error while writing value for characteristic %{private}@: %@",
                log: .bluetooth,
                type: .error,
                characteristic.uuid.uuidString,
                error.debugDescription
            )
        }

        if self.connectableState == .Writing, let timer = self.timer, timer.isValid {
            os_log(
                "Writing chunk was successful, invalidating write timer %{private}@",
                log: .bluetooth,
                type: .debug,
                timer.description
            )
            timer.invalidate()
            self.timer = nil

            self.writeBuffer = [UInt8](self.writeBuffer.dropFirst(self.writingChunk.count))
            self.writeChunk(peripheral, writeCharacteristic: characteristic)
        }
    }
}

// MARK: reading section
extension BluetoothManager {
    func startReading() throws {
        guard self.connectableState == .Connected else {
            os_log(
                "Bluetooth is not in Connected state: %@",
                log: .bluetooth,
                type: .error,
                self.connectableState.description
            )
            throw BluetoothError.NotConnected
        }

        try self.setNotificationState(value: true)
    }

    func stopReading() throws {
        guard self.connectableState == .Reading else {
            os_log(
                "Bluetooth is not in Reading state: %@",
                log: .bluetooth,
                type: .error,
                self.connectableState.description
            )
            throw BluetoothError.NotReading
        }

        try self.setNotificationState(value: false)
    }

    private func setNotificationState(value: Bool) throws {
        guard let readCharacteristic = self.readCharacteristic else {
            os_log("Read characteristic not found", log: .bluetooth, type: .error)
            throw BluetoothError.CharacteristicNotFound
        }

        guard let peripheral = self.discoveredPeripheral else {
            os_log("Peripheral not found", log: .bluetooth, type: .error)
            throw BluetoothError.PeripheralNotFound
        }

        self.timer = Timer.scheduledTimer(
            withTimeInterval: BluetoothConstants.ReadTimeout,
            repeats: false,
            block: { timer in
                os_log(
                    "Read notification timer %{private}@",
                    log: .bluetooth,
                    type: .debug,
                    timer.description
                )
                self.timer = nil
                self.connectableState = .Errored

                self.writableDelegate?.writable(didReceive: nil, BluetoothError.Timeout)
            }
        )
        os_log(
            "Scheduled read notification timer %{private}@",
            log: .bluetooth,
            type: .debug,
            self.timer?.description ?? "Timer not set"
        )

        os_log(
            "Setting read notifications value (%@) to characteristic %{private}@:",
            log: .bluetooth,
            type: .debug,
            value.description,
            peripheral.identifier.uuidString
        )

        peripheral.setNotifyValue(value, for: readCharacteristic)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil else {
            os_log("Error while reading new notification state", log: .bluetooth, type: .error)

            self.connectableState = .Errored
            self.writableDelegate?.writable(didReceive: nil, error)

            return
        }

        if characteristic.uuid.uuidString == BluetoothConstants.ReadCharacteristic {
            os_log(
                "Notification state updated to %@ for characteristic %{private}@",
                log: .bluetooth,
                type: .debug,
                characteristic.isNotifying.description,
                characteristic.uuid.uuidString
            )

            // check if we still need to notify this change
            if let timer = self.timer, timer.isValid {
                os_log(
                    "Invalidating read notification state timeout timer %{private}@",
                    log: .bluetooth,
                    type: .debug,
                    timer.description
                )
                timer.invalidate()
                self.timer = nil
            }
            else {
                os_log("Timer is not set", log: .bluetooth, type: .debug)
            }

            if characteristic.isNotifying {
                self.connectableState = .Reading

                // start a new timeout timer
                self.timer = Timer.scheduledTimer(
                    withTimeInterval: BluetoothConstants.ReadTimeout,
                    repeats: false,
                    block: { timer in
                        os_log(
                            "Read packet timer %{private}@",
                            log: .bluetooth,
                            type: .debug,
                            timer.description
                        )

                        self.timer = nil
                        self.connectableState = .Errored

                        if self.senderConnectableState != .Unknown {
                            peripheral.setNotifyValue(false, for: characteristic)
                        }
                        self.writableDelegate?.writable(didReceive: nil, BluetoothError.Timeout)
                    }
                )

                os_log(
                    "Scheduled read packet timer %{private}@",
                    log: .bluetooth,
                    type: .debug,
                    self.timer?.description ?? "Timer not set"
                )
            }
            else if self.connectableState != .Errored {
                self.connectableState = self.senderConnectableState
                self.writableDelegate?.writable(didStopReading: true, nil)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let timer = self.timer, timer.isValid {
            os_log(
                "Invalidating any existing timer %{private}@",
                log: .bluetooth,
                type: .debug,
                timer.description
            )
            timer.invalidate()
            self.timer = nil
        }

        guard error == nil else {
            os_log(
                "Found error while getting value for characteristic %{private}@:",
                log: .bluetooth,
                type: .error,
                characteristic.uuid.uuidString,
                error.debugDescription
            )
            self.connectableState = .Errored

            self.writableDelegate?.writable(didReceive: nil, error)
            return
        }

        guard characteristic.uuid.uuidString == BluetoothConstants.ReadCharacteristic else {
            os_log(
                "Characteristic %{private}@ not matching %{private}@, skipping",
                log: .bluetooth,
                type: .debug,
                characteristic.uuid.uuidString,
                BluetoothConstants.ReadCharacteristic
            )
            return
        }

        guard let value = characteristic.value else {
            os_log(
                "No value for characteristic %{private}@",
                log: .bluetooth,
                type: .debug,
                characteristic.uuid.uuidString
            )

            self.writableDelegate?.writable(didReceive: [], nil)
            return
        }

        let receivedData = [UInt8](value)
        self.writableDelegate?.writable(didReceive: receivedData, nil)
    }
}

// MARK: connection section
extension BluetoothManager: ConnectableTL {
    private func create() {
        self.centralManager = CBCentralManager.init(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
    }

    @objc private func startupTimer(t: Timer) {
        self.timer = nil

        guard self.connectableState == .Created else {
            self.connectableState = .Errored

            os_log("Bluetooth creation timer error", log: .bluetooth, type: .debug)
            self.connectableDelegate?.create(didCreate: nil, BluetoothError.Timeout)

            return
        }

        let gattService = CBUUID(string: BluetoothConstants.GattService)
        self.connectableDelegate?.create(didCreate: true, nil)

        os_log(
            "Looking for connected peripherals with GATT service %{private}@",
            log: .bluetooth,
            type: .debug,
            BluetoothConstants.GattService
        )

        let connectedPeripherals = self.centralManager.retrieveConnectedPeripherals(withServices: [
            gattService
        ])

        os_log("Starting interface startup Timer", log: .bluetooth, type: .debug)
        self.timer = Timer.scheduledTimer(
            timeInterval: BluetoothConstants.ConnectionTimeout,
            target: self,
            selector: #selector(Self.connectionTimer),
            userInfo: nil,
            repeats: false
        )

        if let lastConnected = connectedPeripherals.last {
            os_log(
                "Connecting to peripheral: %@",
                log: .bluetooth,
                type: .debug,
                lastConnected.identifier.uuidString
            )

            self.discoveredPeripheral = lastConnected
            self.centralManager.connect(lastConnected, options: nil)
        }
        else {
            os_log("Scanning for peripherals", log: .bluetooth, type: .debug)
            self.centralManager.scanForPeripherals(
                withServices: [gattService],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        }
    }

    @objc private func connectionTimer(timer: Timer) {
        self.timer = nil

        guard self.connectableState == .Connected else {
            self.connectableState = .Errored

            os_log("Bluetooth connection timer error", log: .bluetooth, type: .debug)
            self.connectableDelegate?.connect(didConnect: nil, BluetoothError.Timeout)

            self.centralManager.stopScan()
            return
        }

        self.connectableDelegate?.connect(didConnect: true, nil)
    }

    func connect(to macAddress: String) throws {
        guard self.timer == nil else {
            os_log("Bluetooth Api misuse, an action is already running", log: .bluetooth, type: .debug)
            throw BluetoothError.ApiMisuse
        }

        if let address = self.macAddress, address != macAddress {
            //TODO: handle disconnection if connecting to a new device
        }

        self.macAddress = macAddress

        os_log("Starting bluetooth connection timer", log: .bluetooth, type: .debug)
        self.timer = Timer.scheduledTimer(
            timeInterval: BluetoothConstants.StartupTimeout,
            target: self,
            selector: #selector(Self.startupTimer),
            userInfo: nil,
            repeats: false
        )

        self.create()
    }
}

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "BundleIdentifier not set"

    static let bluetooth = OSLog(subsystem: subsystem, category: "🪀 BluetoothManager")
}
