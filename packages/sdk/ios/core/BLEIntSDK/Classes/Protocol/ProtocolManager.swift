//
//  BLEProtocolManager
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import CryptoKit
import Foundation
import K1
import Logging
import os.log

public struct ProtocolCommandResponse {
    internal init(success: Bool, additionalPayload: [UInt8]) {
        self.success = success
        self.additionalPayload = additionalPayload
    }

    public let success: Bool
    public let additionalPayload: [UInt8]

    internal var description: String {
        "Command was \(self.success ? "successful" : "unsuccessful") with additionalPayload \(Data(self.additionalPayload).base64EncodedString())"
    }
}

internal typealias ProtocolResult = Result<ProtocolCommandResponse, ProtocolErrorCode>

internal class ProtocolManager {
    private var privateKey: PrivateKey!
    private var publicKey: PublicKey!

    private var writable: WritableTL!
    private(set) var writableState: WritableTLState?

    private var writeBuffer: [[UInt8]] = []
    private var readBuffer: [UInt8] = []

    private var writeContinuation: CheckedContinuation<ProtocolResult, Error>?
    private var connectionContinuation: CheckedContinuation<Void, Error>?

    private static let logger = LoggingUtil.logger

    init(with writable: WritableTL, privateKey: PrivateKey, publicKey: PublicKey) {
        self.privateKey = privateKey
        self.publicKey = publicKey

        self.writable = writable
        self.writable.writableDelegate = self
        self.writable.connectableDelegate = self
    }

    func setPrivateKey(_ key: PrivateKey) {
        self.privateKey = key
    }

    func connect(to macAddress: String) async throws {
        return try await withCheckedThrowingContinuation { cont in
            guard self.connectionContinuation == nil else {
                cont.resume(throwing: ProtocolError.ApiMisuse)
                return
            }

            do {
                self.connectionContinuation = cont
                try self.writable.connect(to: macAddress)
            }
            catch {
                cont.resume(throwing: error)
                self.connectionContinuation = nil
            }
        }
    }

    func startSession(withAccess data: [UInt8]) async throws -> ProtocolResult {
        return try await self.withThrowingWriteContinuation {
            let personalPublicKey = try self.privateKey.publicKey.rawRepresentation(format: .compressed)

            self.writeBuffer = [
                ProtocolFrame.SessionStart, personalPublicKey + data, ProtocolFrame.SessionEnd,
            ]

            Self.logger.debug(
                "Start session data: \(Data(writeBuffer.joined()).hexEncodedString)",
                metadata: .protocol
            )
            try self.write()
        }
    }

    func sendCommand(withPayload data: [UInt8]) async throws -> ProtocolResult {
        return try await self.withThrowingWriteContinuation {
            do {
                let commandPayload = CommandRequestPayload(data: data)

                let encryptedPacket = try EncryptedCommandPacket.encrypt(
                    commandPayload.encode(),
                    version: ProtocolVersion,
                    privateKey: privateKey,
                    publicKey: publicKey
                ).encode()

                self.writeBuffer = [
                    ProtocolFrame.CommandStart, encryptedPacket, ProtocolFrame.CommandEnd,
                ]
            }
            catch {
                Self.logger.error(
                    "Error while encrypting command data: \(error.localizedDescription)",
                    metadata: .protocol
                )
                throw ProtocolError.Crypto
            }

            Self.logger.info(
                "Sending command data: \(Data(writeBuffer.joined()).hexEncodedString)",
                metadata: .protocol
            )

            try self.write()
        }
    }

    private func withThrowingWriteContinuation(_ body: () throws -> Void) async throws -> ProtocolResult {
        return try await withCheckedThrowingContinuation { cont in
            guard self.writeContinuation == nil else {
                cont.resume(throwing: ProtocolError.ApiMisuse)
                return
            }

            do {
                self.writeContinuation = cont

                try body()
            }
            catch {
                cont.resume(throwing: error)
                self.writeContinuation = nil
            }
        }
    }
}

// MARK: Reading and writing handlers

extension ProtocolManager: WritableTLDelegate {
    private func write() throws {
        guard let nextChunk = self.writeBuffer.first else {
            Self.logger.info("Chunk is empty, starting read", metadata: .protocol)

            do {
                try self.writable.startReading()
            }
            catch {
                Self.logger.error("Error while writing", metadata: .protocol)

                self.writeContinuation?.resume(throwing: error)
                self.writeContinuation = nil
            }
            return
        }

        guard self.writableState == .Connected else {
            Self.logger.info(
                "Writable is not in connected state: \((self.writableState ?? .Reading).description)",
                metadata: .protocol

            )

            self.writeContinuation?.resume(throwing: ProtocolError.Writable)
            self.writeContinuation = nil

            return
        }

        Self.logger.debug("Writing data: \(Data(nextChunk).hexEncodedString)", metadata: .protocol)

        try self.writable.write(data: nextChunk)
    }

    func writable(didWrite remainingData: [UInt8], _ error: Error?) {
        if let error = error {
            Self.logger.error("Error while writing \(error.localizedDescription)", metadata: .protocol)

            self.writeContinuation?.resume(throwing: error)
            self.writeContinuation = nil

            return
        }

        guard remainingData.isEmpty else {
            Self.logger.error(
                "Error while writing, data is not empty: \(remainingData.description)",
                metadata: .protocol
            )

            self.writeContinuation?.resume(throwing: ProtocolError.Generic)
            self.writeContinuation = nil

            return
        }

        self.writeBuffer = [[UInt8]](self.writeBuffer.dropFirst())

        do {
            try self.write()
        }
        catch {
            Self.logger.error("Error while writing \(remainingData.description)", metadata: .protocol)

            self.writeContinuation?.resume(throwing: error)
            self.writeContinuation = nil
        }
    }

    func writable(didReceive data: [UInt8]?, _ error: Error?) {
        guard let receivedData = data, error == nil else {
            Self.logger.error("Error while reading \(error.debugDescription)", metadata: .protocol)

            self.writeContinuation?.resume(throwing: error ?? ProtocolError.Generic)
            self.writeContinuation = nil

            return
        }

        Self.logger.debug("Did receive \(Data(receivedData).hexEncodedString)", metadata: .protocol)

        switch receivedData {
        case ProtocolFrame.SessionStart, ProtocolFrame.CommandStart:
            self.readBuffer = [UInt8](receivedData)
        case ProtocolFrame.SessionEnd, ProtocolFrame.CommandEnd:
            self.readBuffer += receivedData

            Self.logger.debug(
                "Read end frame, closing",
                metadata: .protocol
            )

            do {
                try self.writable.stopReading()
            }
            catch {
                Self.logger.error(
                    "Error while stop reading \(error.localizedDescription)",
                    metadata: .protocol
                )

                self.writeContinuation?.resume(throwing: error)
                self.writeContinuation = nil
            }
        default:
            self.readBuffer += receivedData
        }
    }

    func writable(didStopReading: Bool, _ error: Error?) {
        do {
            Self.logger.info("Received data: \(Data(self.readBuffer).hexEncodedString)", metadata: .protocol)

            let startFrame = [UInt8](self.readBuffer.prefix(4))
            let payload: [UInt8] = self.readBuffer.dropFirst(4).dropLast(4)

            Self.logger.debug(
                "DidStopReading start frame: \(startFrame.description)",
                metadata: .protocol
            )

            switch startFrame {
            case ProtocolFrame.SessionStart, ProtocolFrame.CommandStart:
                self.processEncryptedCommandResponse(try EncryptedCommandPacket(from: payload))
            default:
                throw ProtocolError.InvalidData("Invalid protocol start frame")
            }
        }
        catch {
            Self.logger.error(
                "Error while parsing packets \(error.localizedDescription)",
                metadata: .protocol
            )
            self.writeContinuation?.resume(throwing: error)
            self.writeContinuation = nil
        }
    }

    func connection(didChangeState state: WritableTLState) {
        Self.logger.info(
            "Did change status: \(self.writableState?.description ?? "nil") -> \(state.description)",
            metadata: .protocol
        )
        self.writableState = state
    }
}

// MARK: Connection handlers

extension ProtocolManager: ConnectableTLDelegate {
    func create(didCreate data: Any?, _ error: Error?) {
        guard error == nil else {
            Self.logger.error(
                "Creation Error \(error?.localizedDescription ?? "Error not set")",
                metadata: .protocol
            )

            self.connectionContinuation?.resume(throwing: ProtocolError.Writable)
            self.connectionContinuation = nil

            return
        }

        Self.logger.info("Writable created", metadata: .protocol)
    }

    func connect(didConnect data: Any?, _ error: Error?) {
        guard error == nil else {
            Self.logger.error(
                "Connection Error \(error?.localizedDescription ?? "Error not set")",
                metadata: .protocol
            )

            self.connectionContinuation?.resume(throwing: error ?? ProtocolError.Writable)
            self.connectionContinuation = nil

            return
        }

        Self.logger.info("Writable connected", metadata: .protocol)

        self.connectionContinuation?.resume()
        self.connectionContinuation = nil
    }
}

// MARK: Packet handlers

extension ProtocolManager {
    private func processEncryptedCommandResponse(_ packet: EncryptedCommandPacket) {
        Self.logger.debug(
            "Received encrypted command response \(Data(packet.data).hexEncodedString)",
            metadata: .protocol
        )

        do {
            let decryptedData = try packet.decrypt(privateKey: self.privateKey, publicKey: self.publicKey)
            Self.logger.debug(
                "Decrypted command data: \(Data(decryptedData).hexEncodedString)",
                metadata: .protocol
            )

            let commandPayload = try CommandResponsePayload.init(from: decryptedData)

            if commandPayload.commandIdentifier != .Error {
                self.writeContinuation?.resume(
                    returning: .success(
                        .init(success: commandPayload.commandIdentifier == .Ack, additionalPayload: commandPayload.data)
                    )
                )
            }
            else {
                let errorPayload = try ErrorCommandPayload.init(from: commandPayload.data)

                self.writeContinuation?.resume(returning: .failure(errorPayload.errorCode))
            }
        }
        catch let error as CryptoKitError {
            Self.logger.error("CryptoKit error \(error.description)", metadata: .protocol)
            self.writeContinuation?.resume(throwing: error)
        }
        catch {
            Self.logger.error("Error while decrypting data \(error.localizedDescription)", metadata: .protocol)
            self.writeContinuation?.resume(throwing: error)
        }

        self.writeContinuation = nil
    }
}

// MARK: extensions
extension ProtocolErrorCode: Error {}

extension Logging.Logger.Metadata {
    fileprivate static var `protocol`: Self {
        var metadata: Self = ["category": "🔀 ProtocolManager"]

        if let requestId = Self.requestId {
            metadata["requestId"] = "\(requestId)"
        }

        return metadata
    }
}
