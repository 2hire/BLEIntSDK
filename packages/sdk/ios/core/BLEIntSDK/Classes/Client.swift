//
//  Client
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation
import os.log

public typealias CommandResponse = ProtocolResponse

public class Client {
    private var personalPrivateKey: PrivateKey?
    private var sessionData: SessionData?

    private var manager: ProtocolManager?

    private var identifier: String?

    public init() {}

    public func sessionSetup(with data: SessionData) throws {
        os_log("Getting PrivateKey from KeyChain", log: .client, type: .debug)
        let privateKey = try KeychainHelper.getOrGeneratePrivateKey()
        let publicKey = try CryptoHelper.wrapPublicKey(from: data.publicKey.rawFromBase64Encoded)

        self.sessionData = data

        os_log("Creating ProtocolManager", log: .client, type: .debug)
        self.manager = ProtocolManager.init(
            with: BluetoothManager.shared,
            privateKey: privateKey,
            publicKey: publicKey
        )
    }

    public func connectToVehicle(withIdentifier macAddress: String) async throws -> CommandResponse {
        guard let manager = self.manager,
            let sessionData = self.sessionData,
            let command = sessionData.commands[.Noop]
        else {
            os_log("Error while connecting to vehicle", log: .client, type: .debug)
            throw ClientError.InvalidState
        }

        self.identifier = macAddress

        try await self._connect()

        os_log("Sending Noop command to retrieve connection status", log: .client, type: .debug)

        guard
            let noopResponse = try? await manager.sendCommand(withPayload: command.rawFromBase64Encoded)
        else {
            os_log("Noop failed, reconnecting", log: .client, type: .debug)
            try await manager.connect(to: macAddress)

            os_log("Generating a new PrivateKey", log: .client, type: .debug)
            let privateKey = try KeychainHelper.generateAndSavePrivateKey()
            manager.setPrivateKey(privateKey)

            os_log("Starting a new session", log: .client, type: .debug)
            return try await manager.startSession(
                withAccess: sessionData.accessToken.rawFromBase64Encoded
            )
        }

        return noopResponse
    }

    private func _connect() async throws {
        guard let manager = self.manager, let identifier = self.identifier else {
            os_log("Error while connecting to vehicle", log: .client, type: .debug)
            throw ClientError.InvalidState
        }

        os_log(
            "ProtocolManager status: %@",
            log: .client,
            type: .debug,
            manager.writableState?.description ?? "nil"
        )
        if manager.writableState != .Connected {
            os_log("Connecting", log: .client, type: .debug)
            try await manager.connect(to: identifier)
        }
    }

    public func sendCommand(type: CommandType) async throws -> CommandResponse {
        return try await self._sendCommand(type: type)
    }

    public func endSession() async throws -> CommandResponse {
        let data = try await self._sendCommand(type: .EndSession)

        self.personalPrivateKey = nil
        self.sessionData = nil
        self.manager = nil
        self.identifier = nil

        return data
    }

    private func _sendCommand(type: CommandType) async throws
        -> CommandResponse
    {
        guard let manager = self.manager, let sessionData = self.sessionData,
            let command = sessionData.commands[type]
        else {
            os_log("Error while sending command", log: .client, type: .debug)
            throw ClientError.InvalidState
        }

        if manager.writableState != .Connected {
            os_log("Connecting to vehicle", log: .client, type: .debug)
            try await self._connect()
        }
        else {
            os_log("Vehicle is already connecting, skipping", log: .client, type: .debug)
        }

        os_log("Sending command", log: .client, type: .debug)
        return try await manager.sendCommand(withPayload: command.rawFromBase64Encoded)
    }
}

extension String {
    fileprivate var rawFromBase64Encoded: [UInt8] {
        get throws {
            guard let data = Data(base64Encoded: self) else {
                throw ClientError.InvalidDataError
            }

            return [UInt8](data)
        }
    }
}

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "BundleIdentifier not set"

    fileprivate static let client = OSLog(subsystem: subsystem, category: "🎟 Client")
}

