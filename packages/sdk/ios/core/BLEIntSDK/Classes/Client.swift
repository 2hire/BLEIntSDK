//
//  Client
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation
import Logging
import os.log

public typealias CommandResponse = ProtocolResponse

public class Client {
    private var personalPrivateKey: PrivateKey?
    private var sessionData: SessionData?

    private var manager: ProtocolManager?
    private var writableStateHistory: [WritableTLState] = []

    private var identifier: String?

    private static let logger = LoggingUtil.logger

    public init() {}

    public func sessionSetup(with data: SessionData) throws {
        do {
            Logger.Metadata.requestId = UUID().uuidString

            Self.logger.info("Getting PrivateKey from KeyChain", metadata: .client)
            let privateKey = try KeychainHelper.getOrGeneratePrivateKey()
            let publicKey = try CryptoHelper.wrapPublicKey(from: data.publicKey.rawFromBase64Encoded)

            self.sessionData = data

            Self.logger.info("Creating ProtocolManager \(sessionData?.description ?? "null")", metadata: .client)
            self.manager = ProtocolManager.init(
                with: BluetoothManager.shared,
                privateKey: privateKey,
                publicKey: publicKey,
                delegate: self
            )

            self.writableStateHistory = []
        }
        catch {
            throw try Self.logAndMapError(error)
        }
    }

    public func connectToVehicle(withIdentifier macAddress: String) async throws -> CommandResponse {
        return try await Self.catchInternalError {
            guard let manager = self.manager
            else {
                Self.logger.error("Error while connecting to vehicle, manager is nil", metadata: .client)
                throw ClientError.InvalidState
            }

            guard let sessionData = self.sessionData
            else {
                Self.logger.error("Error while connecting to vehicle, sessionData is nil", metadata: .client)
                throw ClientError.InvalidState
            }

            guard let command = sessionData.commands[.Noop]
            else {
                Self.logger.error("Error while connecting to vehicle, noop command is nil", metadata: .client)
                throw ClientError.InvalidState
            }

            self.identifier = macAddress
            var invalidSessionNoop = false

            try await self._connect()

            do {
                Self.logger.info("Sending Noop command to retrieve connection status", metadata: .client)
                guard
                    let noopResponse =
                        try? await manager.sendCommand(withPayload: command.rawFromBase64Encoded)
                else {
                    Self.logger.info("Noop failed, reconnecting", metadata: .client)

                    if ClientError.checkInvalidSession(for: writableStateHistory) {
                        Self.logger.info("Noop failed for an InvalidSession", metadata: .client)
                        invalidSessionNoop = true
                    }

                    try await manager.connect(to: macAddress)

                    Self.logger.info("Generating a new PrivateKey", metadata: .client)
                    let privateKey = try KeychainHelper.generateAndSavePrivateKey()
                    manager.setPrivateKey(privateKey)

                    Self.logger.info("Starting a new session", metadata: .client)

                    let response = try await manager.startSession(
                        withAccess: sessionData.accessToken.rawFromBase64Encoded
                    )

                    Self.logger.info("Start session response: \"\(response.description)\"")

                    return response
                }

                return noopResponse
            }
            catch {
                if invalidSessionNoop && ClientError.checkInvalidSession(for: writableStateHistory) {
                    Self.logger.info(
                        "ConnectToVehicle failed with two consecutive InvalidSession errors",
                        metadata: .client
                    )

                    throw ClientError.InvalidSession
                }

                Self.logger.info("ConnectToVehicle failed with \(error.localizedDescription)", metadata: .client)

                throw error
            }
        }
    }

    public func sendCommand(type: CommandType) async throws -> CommandResponse {
        return try await Self.catchInternalError {
            Self.logger.info("Preparing to send command: \(type.rawValue)", metadata: .client)

            return try await self._sendCommand(type: type)
        }
    }

    public func endSession() async throws -> CommandResponse {
        return try await Self.catchInternalError {
            let data = try await self._sendCommand(type: .EndSession)

            self.personalPrivateKey = nil
            self.sessionData = nil
            self.manager = nil
            self.identifier = nil
            self.writableStateHistory = []

            return data
        }
    }

    private func _connect() async throws {
        guard let manager = self.manager
        else {
            Self.logger.error("Error while connecting to vehicle, manager is nil", metadata: .client)
            throw ClientError.InvalidState
        }

        guard let identifier = self.identifier
        else {
            Self.logger.error("Error while connecting to vehicle, identifier is nil", metadata: .client)
            throw ClientError.InvalidState
        }

        Self.logger.info(
            "ProtocolManager status: \( manager.writableState?.description ?? "nil")",
            metadata: .client
        )

        if manager.writableState != .Connected {
            Self.logger.info("Connecting", metadata: .client)
            try await manager.connect(to: identifier)
        }
    }

    private func _sendCommand(type: CommandType) async throws
        -> CommandResponse
    {
        guard let manager = self.manager
        else {
            Self.logger.error("Error while connecting to vehicle, manager is nil", metadata: .client)
            throw ClientError.InvalidState
        }

        guard let sessionData = self.sessionData
        else {
            Self.logger.error("Error while sending command, sessionData is nil", metadata: .client)
            throw ClientError.InvalidState
        }

        guard let command = sessionData.commands[type]
        else {
            Self.logger.error("Error while sending command, command is nil", metadata: .client)
            throw ClientError.InvalidState
        }

        if manager.writableState != .Connected {
            Self.logger.info("Connecting to vehicle", metadata: .client)
            try await self._connect()
        }
        else {
            Self.logger.info("Vehicle is already connected, skipping", metadata: .client)
        }

        Self.logger.info("Sending command: \(type.rawValue)", metadata: .client)

        let response = try await manager.sendCommand(withPayload: command.rawFromBase64Encoded)

        Self.logger.info("Command response: \"\(response.description)\"", metadata: .client)

        return response
    }

    private static func catchInternalError<T>(throwingCallback: () async throws -> T) async throws -> T {
        do {
            return try await throwingCallback()
        }
        catch {
            throw try logAndMapError(error)
        }
    }

    private static func logAndMapError(_ error: Error) throws -> Error {
        let internalError = BLEIntSDKError.from(error: error)
        Self.logger.error(
            "[\(internalError.rawValue)]: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)",
            metadata: .client
        )

        return internalError
    }
}

extension Client: ProtocolManagerDelegate {
    func state(didChange state: WritableTLState) {
        self.writableStateHistory.append(state)
    }
}

extension String {
    fileprivate var rawFromBase64Encoded: [UInt8] {
        get throws {
            guard let data = Data(base64Encoded: self) else {
                throw ClientError.InvalidData
            }

            return [UInt8](data)
        }
    }
}

extension Logging.Logger.Metadata {
    static var requestId: String?

    fileprivate static var client: Self {
        var metadata: Self = ["category": "🎟 Client"]

        if let requestId = Self.requestId {
            metadata["requestId"] = "\(requestId)"
        }

        return metadata
    }
}
