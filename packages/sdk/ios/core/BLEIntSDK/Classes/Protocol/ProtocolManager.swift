//
//  BLEProtocolManager
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation
import K1
import Logging
import os.log

public struct ProtocolResponse {
    public let success: Bool
    public let additionalPayload: [UInt8]

    internal var description: String {
        "Command was \(self.success ? "successful" : "unsuccessful") with additionalPayload \(Data(self.additionalPayload).base64EncodedString())"
    }
}

internal class ProtocolManager {
    private var privateKey: PrivateKey!
    private var publicKey: PublicKey!

    private var writable: WritableTL!
    private(set) var writableState: WritableTLState? {
        didSet {
            if let state = self.writableState {
                self.delegate?.state(didChange: state)
            }
        }
    }

    private var delegate: ProtocolManagerDelegate?

    private var writeBuffer: [[UInt8]] = []
    private var readBuffer: [UInt8] = []

    private var writeContinuation: CheckedContinuation<ProtocolResponse, Error>?
    private var connectionContinuation: CheckedContinuation<Void, Error>?

    private static let logger = LoggingUtil.logger

    init(
        with writable: WritableTL,
        privateKey: PrivateKey,
        publicKey: PublicKey,
        delegate: ProtocolManagerDelegate
    ) {
        self.privateKey = privateKey
        self.publicKey = publicKey

        self.writable = writable
        self.writable.writableDelegate = self
        self.writable.connectableDelegate = self

        self.delegate = delegate
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

    func startSession(withAccess data: [UInt8]) async throws -> ProtocolResponse {
        return try await withCheckedThrowingContinuation { cont in
            guard self.writeContinuation == nil else {
                cont.resume(throwing: ProtocolError.ApiMisuse)
                return
            }

            do {
                self.writeContinuation = cont
                let personalPublicKey = try self.privateKey.publicKey.rawRepresentation(format: .compressed)
                self.writeBuffer = [
                    ProtocolConstant.StartSequence, personalPublicKey + data, ProtocolConstant.EndSequence,
                ]

                Self.logger.debug(
                    "Start session data \(writeBuffer.description)",
                    metadata: .protocol

                )
                try self.write()
            }
            catch {
                cont.resume(throwing: error)
                self.writeContinuation = nil
            }
        }
    }

    func sendCommand(withPayload data: [UInt8]) async throws -> ProtocolResponse {
        return try await withCheckedThrowingContinuation { cont in
            guard self.writeContinuation == nil else {
                cont.resume(throwing: ProtocolError.ApiMisuse)
                return
            }

            do {
                self.writeContinuation = cont

                let commandPayload = try Self.createCommand(
                    withPayload: data,
                    privateKey: self.privateKey,
                    publicKey: self.publicKey
                )
                self.writeBuffer = [
                    ProtocolConstant.StartSequence, commandPayload, ProtocolConstant.EndSequence,
                ]

                Self.logger.info(
                    "Sending command data: \(writeBuffer.description)",
                    metadata: .protocol

                )
                try self.write()
            }
            catch {
                cont.resume(throwing: error)
                self.writeContinuation = nil
            }
        }
    }

    private static func createCommand(
        withPayload data: [UInt8],
        privateKey: PrivateKey,
        publicKey: PublicKey
    ) throws -> [UInt8] {
        var dataToEncrypt = [ProtocolMessageType.Request.rawValue]

        dataToEncrypt.append(contentsOf: Date().timestamp.prefix(4))
        dataToEncrypt.append(contentsOf: data)

        do {
            let nonce = try CryptoHelper.generateNonce(length: 16)
            let sealedBox = try CryptoHelper.encrypt(
                data: dataToEncrypt,
                .init(privateKey: privateKey, publicKey: publicKey, nonce: nonce)
            )

            guard let encryptedData = sealedBox else {
                throw ProtocolError.Crypto
            }

            var dataToWrite = Data()

            dataToWrite.append(contentsOf: [ProtocolVersion])
            dataToWrite.append(contentsOf: encryptedData.nonce)
            dataToWrite.append(contentsOf: encryptedData.tag)
            dataToWrite.append(contentsOf: encryptedData.ciphertext)

            return [UInt8](dataToWrite)
        }
        catch {
            Self.logger.error(
                "Error while encrypting command data: \(error.localizedDescription)",
                metadata: .protocol
            )
            throw ProtocolError.Crypto
        }
    }

    private static func decryptCommand(
        withPayload data: [UInt8],
        privateKey: PrivateKey,
        publicKey: PublicKey
    ) throws -> [UInt8]? {
        do {
            let nonce = [UInt8](data[1...16])
            let tag = [UInt8](data[17...32])
            let encryptedPayload = [UInt8](data[33...])

            #if DEBUG
                Self.logger.debug("Buffer length \(data.count)", metadata: .protocol)
                Self.logger.debug("Nonce: \(Data(nonce).hexEncodedString)", metadata: .protocol)
                Self.logger.debug("Tag: \(Data(tag).hexEncodedString)", metadata: .protocol)
                Self.logger.debug(
                    "Private key: \(Data(privateKey.rawRepresentation()).hexEncodedString)",
                    metadata: .protocol
                )
            #endif

            return try CryptoHelper.decrypt(
                cipherText: encryptedPayload,
                .init(
                    privateKey: privateKey,
                    publicKey: publicKey,
                    nonce: AES.GCM.Nonce(data: nonce),
                    tag: tag
                )
            )
        }
        catch let err as CryptoKitError {
            Self.logger.error("CryptoKit error \(err.description)", metadata: .protocol)
        }
        catch {
            Self.logger.error("Error while decrypting data", metadata: .protocol)
        }

        throw ProtocolError.Crypto
    }

    private func processCommandResponse(payload: [UInt8]) {
        let validity = payload[5]
        let additionalPayload = [UInt8](payload[6...])

        if validity == ProtocolConstant.Ack {
            self.writeContinuation?.resume(
                returning: .init(success: true, additionalPayload: additionalPayload)
            )
        }
        else if validity == ProtocolConstant.Nack {
            self.writeContinuation?.resume(
                returning: .init(success: false, additionalPayload: additionalPayload)
            )
        }
        else {
            self.writeContinuation?.resume(throwing: ProtocolError.InvalidData)
        }

        self.writeContinuation = nil
    }
}

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

        #if DEBUG
            Self.logger.debug("Writing data \(writeBuffer.description)", metadata: .protocol)
        #else
            Self.logger.info("Writing data", metadata: .protocol)
        #endif

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
            Self.logger.error("Error while reading \(error.debugDescription))", metadata: .protocol)

            self.writeContinuation?.resume(throwing: error ?? ProtocolError.Generic)
            self.writeContinuation = nil

            return
        }

        Self.logger.debug("Did receive \(receivedData.description))", metadata: .protocol)

        switch receivedData {
        case ProtocolConstant.StartSequence:
            self.readBuffer = []
            Self.logger.debug(
                "Read start sequence: \(receivedData.description), skipping",
                metadata: .protocol

            )

            break
        case ProtocolConstant.EndSequence:
            Self.logger.debug(
                "Read end sequence: \(receivedData.description), closing",
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

            break
        default:
            self.readBuffer += receivedData
        }
    }

    func writable(didStopReading: Bool, _ error: Error?) {
        do {
            let decryptedData = try Self.decryptCommand(
                withPayload: self.readBuffer,
                privateKey: self.privateKey,
                publicKey: self.publicKey
            )

            if let decryptedDataValue = decryptedData {
                Self.logger.info(
                    "Decrypted data \(Data(decryptedDataValue).hexEncodedString)",
                    metadata: .protocol
                )

                self.processCommandResponse(payload: decryptedDataValue)
            }
            else {
                throw ProtocolError.Generic
            }
        }
        catch {
            Self.logger.error(
                "Error while stop reading \(error.localizedDescription)",
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

extension Logging.Logger.Metadata {
    fileprivate static var `protocol`: Self {
        var metadata: Self = ["category": "🔀 ProtocolManager"]

        if let requestId = Self.requestId {
            metadata["requestId"] = "\(requestId)"
        }

        return metadata
    }
}
