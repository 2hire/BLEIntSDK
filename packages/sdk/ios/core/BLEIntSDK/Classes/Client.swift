//
//  Client
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation
import Logging
import os.log

public typealias CommandResponse = ProtocolCommandResponse

public class Client {
    private var personalPrivateKey: PrivateKey?
    private var sessionData: SessionData?

    private var manager: ProtocolManager?

    private var identifier: String?

    private static let logger = LoggingUtil.logger

    public init() {}

    public func sessionSetup(with data: SessionData) throws {
        do {
            Logger.Metadata.requestId = UUID().uuidString

            Self.logger.info("Getting PrivateKey from KeyChain", metadata: .client)

            let privateKey = try KeychainHelper.getOrGeneratePrivateKey(with: 86_400)
            let publicKey = try CryptoHelper.wrapPublicKey(from: data.publicKey.rawFromBase64Encoded)

            self.sessionData = data

            Self.logger.info("Creating ProtocolManager \(sessionData?.description ?? "null")", metadata: .client)
            self.manager = ProtocolManager.init(
                with: BluetoothManager.shared,
                privateKey: privateKey,
                publicKey: publicKey
            )
        }
        catch {
            throw try Self.logAndMapError(error)
        }
    }

    public func connectToVehicle(withIdentifier macAddress: String) async throws -> CommandResponse? {
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

            Self.logger.info("Connecting to vehicle with identifier: \(macAddress)")

            self.identifier = macAddress
            try await self._connect()

            do {
                let privateKey = try KeychainHelper.getOrGeneratePrivateKey()
                manager.setPrivateKey(privateKey)

                do {
                    return try await manager.startSession(
                        withAccess: sessionData.accessToken.rawFromBase64Encoded
                    ).get()
                }
                catch ProtocolErrorCode.AlreadyValidated {
                    Self.logger.info("Session is still valid", metadata: .client)

                    return nil
                }
                catch let error as ProtocolErrorCode {
                    Self.logger.error("Received protocol error code \(error.rawValue)", metadata: .client)
                    throw ClientError.InvalidSession(errorCode: "\(error.rawValue)")
                }
            }
            catch {
                Self.logger.error("Error while creating session, removing PrivateKey", metadata: .client)
                try KeychainHelper.deletePrivateKey()

                throw error
            }
        }
    }

    public func sendCommand(type: CommandType) async throws -> CommandResponse {
        guard type != .EndSession
        else {
            throw BLEIntSDKError.InvalidCommand("Cannot send end_session command directly, use endSession() instead")
        }

        return try await Self.catchInternalError {
            return try await self._sendCommand(type: type)
        }
    }

    public func endSession() async throws -> CommandResponse {
        return try await Self.catchInternalError {
            defer {
                do {
                    Self.logger.info("Session was closed, removing PrivateKey", metadata: .client)
                    try KeychainHelper.deletePrivateKey()
                }
                catch {
                    Self.logger.error(
                        "Error while removing PrivateKey: \(error.localizedDescription)",
                        metadata: .client
                    )
                }
            }

            let data = try await self._sendCommand(type: .EndSession)

            self.personalPrivateKey = nil
            self.sessionData = nil
            self.manager = nil
            self.identifier = nil

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
        Self.logger.info("Sending command: \(type.rawValue)", metadata: .client)

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

        do {
            let response = try await manager.sendCommand(withPayload: command.rawFromBase64Encoded).get()
            Self.logger.info("Command response: \"\(response.description)\"", metadata: .client)

            return response
        }
        catch let error as ProtocolErrorCode {
            Self.logger.error("Received protocol error code \(error.rawValue)", metadata: .client)
            throw ClientError.InvalidCommand(errorCode: "\(error.rawValue)")
        }
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
