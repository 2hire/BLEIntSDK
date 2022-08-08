//
//  BluetoothManager
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import CoreBluetooth
import Foundation
import Logging
import os.log

internal class BluetoothManager: NSObject {
    static let shared: BluetoothManager = BluetoothManager()

    internal static let logger = LoggingUtil.logger

    var connectableState: WritableTLState = .Unknown {
        didSet {
            if oldValue != self.connectableState {
                Self.logger.info(
                    "Status changed (\(oldValue.description) -> \(self.connectableState.description))",
                    metadata: .bluetooth
                )
                self.senderConnectableState = oldValue

                self.connectableDelegate?.connection(didChangeState: self.connectableState)
            }

            if let timer = self.timer {
                Self.logger.debug("Firing timer \(timer.description)", metadata: .bluetooth)
                timer.fire()
            }

            if let peripheral = self.discoveredPeripheral, peripheral.state == .connected {
                peripheral.readRSSI()
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
            Self.logger.error("Bluetooth is not connected", metadata: .bluetooth)

            throw BluetoothError.NotConnected
        }

        guard let writeCharacteristic = self.writeCharacteristic else {
            Self.logger.error("Write characteristic not found", metadata: .bluetooth)
            throw BluetoothError.CharacteristicNotFound
        }

        guard let peripheral = self.discoveredPeripheral else {
            Self.logger.error("Peripheral not found", metadata: .bluetooth)
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
            Self.logger.info(
                "Write buffer empty, current status \(self.connectableState.description), resetting to previous status \(self.senderConnectableState.description)",
                metadata: .bluetooth
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

        Self.logger.debug(
            "Scheduled write timer \(self.timer?.description ?? "Timer not set")",
            metadata: .bluetooth
        )
        Self.logger.debug("Writing chunk \(chunkData.hexEncodedString)", metadata: .bluetooth)

        peripheral.writeValue(chunkData, for: characteristic, type: .withResponse)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil else {
            self.connectableState = .Errored

            return Self.logger.error(
                "Found error while writing value for characteristic \(characteristic.uuid.uuidString): \( error.debugDescription)",
                metadata: .bluetooth
            )
        }

        if self.connectableState == .Writing, let timer = self.timer, timer.isValid {
            Self.logger.debug(
                "Writing chunk was successful, invalidating write timer \(timer.description)",
                metadata: .bluetooth
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
            Self.logger.error(
                "Bluetooth is not in Connected state: \(self.connectableState.description)",
                metadata: .bluetooth
            )
            throw BluetoothError.NotConnected
        }

        try self.setNotificationState(value: true)
    }

    func stopReading() throws {
        guard self.connectableState == .Reading else {
            Self.logger.error(
                "Bluetooth is not in Reading state: \(self.connectableState.description)",
                metadata: .bluetooth
            )
            throw BluetoothError.NotReading
        }

        try self.setNotificationState(value: false)
    }

    private func setNotificationState(value: Bool) throws {
        guard let readCharacteristic = self.readCharacteristic else {
            Self.logger.error("Read characteristic not found", metadata: .bluetooth)
            throw BluetoothError.CharacteristicNotFound
        }

        guard let peripheral = self.discoveredPeripheral else {
            Self.logger.error("Peripheral not found", metadata: .bluetooth)
            throw BluetoothError.PeripheralNotFound
        }

        self.timer = Timer.scheduledTimer(
            withTimeInterval: BluetoothConstants.ReadTimeout,
            repeats: false,
            block: { timer in
                Self.logger.debug(
                    "Read notification timer \(timer.description)",
                    metadata: .bluetooth
                )
                self.timer = nil
                self.connectableState = .Errored

                self.writableDelegate?.writable(didReceive: nil, BluetoothError.Timeout)
            }
        )
        Self.logger.debug(
            "Scheduled read notification timer \(self.timer?.description ?? "Timer not set")",
            metadata: .bluetooth
        )

        Self.logger.info(
            "Setting read notifications value (\(value.description)) to characteristic \(peripheral.identifier.uuidString):",
            metadata: .bluetooth
        )

        peripheral.setNotifyValue(value, for: readCharacteristic)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil else {
            Self.logger.error("Error while reading new notification state", metadata: .bluetooth)

            self.connectableState = .Errored
            self.writableDelegate?.writable(didReceive: nil, error)

            return
        }

        if characteristic.uuid.uuidString == BluetoothConstants.ReadCharacteristic {
            Self.logger.info(
                "Notification state updated to \(characteristic.isNotifying.description) for characteristic \( characteristic.uuid.uuidString)",
                metadata: .bluetooth
            )

            // check if we still need to notify this change
            if let timer = self.timer, timer.isValid {
                Self.logger.debug(
                    "Invalidating read notification state timeout timer \( timer.description)",
                    metadata: .bluetooth
                )
                timer.invalidate()
                self.timer = nil
            }
            else {
                Self.logger.debug("Timer is not set", metadata: .bluetooth)
            }

            if characteristic.isNotifying {
                self.connectableState = .Reading

                // start a new timeout timer
                self.timer = Timer.scheduledTimer(
                    withTimeInterval: BluetoothConstants.ReadTimeout,
                    repeats: false,
                    block: { timer in
                        Self.logger.debug(
                            "Read packet timer \(timer.description)",
                            metadata: .bluetooth
                        )

                        self.timer = nil
                        self.connectableState = .Errored

                        if self.senderConnectableState != .Unknown {
                            peripheral.setNotifyValue(false, for: characteristic)
                        }
                        self.writableDelegate?.writable(didReceive: nil, BluetoothError.Timeout)
                    }
                )

                Self.logger.debug(
                    "Scheduled read packet timer \( self.timer?.description ?? "Timer not set")",
                    metadata: .bluetooth
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
            Self.logger.debug(
                "Invalidating any existing timer \(timer.description)",
                metadata: .bluetooth
            )
            timer.invalidate()
            self.timer = nil
        }

        guard error == nil else {
            Self.logger.error(
                "Found error while getting value for characteristic \(characteristic.uuid.uuidString): \(error.debugDescription)",
                metadata: .bluetooth
            )
            self.connectableState = .Errored

            self.writableDelegate?.writable(didReceive: nil, error)
            return
        }

        guard characteristic.uuid.uuidString == BluetoothConstants.ReadCharacteristic else {
            Self.logger.info(
                "Characteristic \(characteristic.uuid.uuidString) not matching \( BluetoothConstants.ReadCharacteristic), skipping",
                metadata: .bluetooth
            )
            return
        }

        guard let value = characteristic.value else {
            Self.logger.info(
                "No value for characteristic \(characteristic.uuid.uuidString)",
                metadata: .bluetooth
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

            Self.logger.error("Bluetooth creation timer error", metadata: .bluetooth)
            self.connectableDelegate?.create(didCreate: nil, BluetoothError.Timeout)

            return
        }

        let gattService = CBUUID(string: BluetoothConstants.GattService)
        self.connectableDelegate?.create(didCreate: true, nil)

        Self.logger.info(
            "Looking for connected peripherals with GATT service \(BluetoothConstants.GattService)",
            metadata: .bluetooth
        )

        let connectedPeripherals = self.centralManager.retrieveConnectedPeripherals(withServices: [
            gattService
        ])

        Self.logger.debug("Starting interface startup Timer", metadata: .bluetooth)
        self.timer = Timer.scheduledTimer(
            timeInterval: BluetoothConstants.ConnectionTimeout,
            target: self,
            selector: #selector(Self.connectionTimer),
            userInfo: nil,
            repeats: false
        )

        if let lastConnected = connectedPeripherals.last {
            Self.logger.info(
                "Connecting to peripheral: \(lastConnected.identifier.uuidString)",
                metadata: .bluetooth
            )

            self.discoveredPeripheral = lastConnected
            self.centralManager.connect(lastConnected, options: nil)
        }
        else {
            Self.logger.info("Scanning for peripherals", metadata: .bluetooth)
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

            Self.logger.error("Bluetooth connection timer error", metadata: .bluetooth)
            self.connectableDelegate?.connect(didConnect: nil, BluetoothError.Timeout)

            self.centralManager.stopScan()
            return
        }

        self.connectableDelegate?.connect(didConnect: true, nil)
    }

    func connect(to macAddress: String) throws {
        guard self.timer == nil else {
            Self.logger.error("Bluetooth Api misuse, an action is already running", metadata: .bluetooth)
            throw BluetoothError.ApiMisuse
        }

        if let address = self.macAddress, address != macAddress {
            //TODO: handle disconnection if connecting to a new device
        }

        self.macAddress = macAddress

        Self.logger.debug("Starting bluetooth connection timer", metadata: .bluetooth)
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

extension Logging.Logger.Metadata {
    static var bluetooth: Self {
        var metadata: Self = ["category": "🪀 BluetoothManager"]

        if let requestId = Self.requestId {
            metadata["requestId"] = "\(requestId)"
        }

        return metadata
    }
}
