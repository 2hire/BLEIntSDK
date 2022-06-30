//
//  BLEProtocolManager
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation
import _2hire_K1
import os.log

public struct ProtocolResponse {
    public let success: Bool
    public let additionalPayload: [UInt8]

    internal var description: String {
        "Command was \(self.success ? "successful" : "unsuccessful") with additionalPayload \(self.additionalPayload.description)"
    }
}

internal class ProtocolManager {
    private var privateKey: PrivateKey!
    private var publicKey: PublicKey!

    private var writable: WritableTL!
    private(set) var writableState: WritableTLState?

    private var writeBuffer: [[UInt8]] = []
    private var readBuffer: [UInt8] = []

    private var writeContinuation: CheckedContinuation<ProtocolResponse, Error>?
    private var connectionContinuation: CheckedContinuation<Void, Error>?

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

                os_log(
                    "Start session data %{private}@",
                    log: .protocol,
                    type: .default,
                    writeBuffer.description
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

                os_log(
                    "Sending command data: %{private}@",
                    log: .protocol,
                    type: .default,
                    writeBuffer.description
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
            os_log(
                "Error while encrypting command data: %@",
                log: .protocol,
                type: .error,
                error.localizedDescription
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
                os_log("Buffer length %{private}d", log: .protocol, type: .default, data.count)
                os_log("Nonce: %{private}@", log: .protocol, type: .default, Data(nonce).hexEncodedString)
                os_log("Tag: %{private}@", log: .protocol, type: .default, Data(tag).hexEncodedString)
                os_log(
                    "Private key: %{private}@",
                    log: .protocol,
                    type: .default,
                    Data(privateKey.rawRepresentation()).hexEncodedString
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
            os_log("CryptoKit error %@", log: .protocol, type: .error, err.description)
        }
        catch {
            os_log("Error while decrypting data %@", log: .protocol, type: .error)
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
            os_log("Chunk is empty, starting read", log: .protocol, type: .default)

            do {
                try self.writable.startReading()
            }
            catch {
                os_log("Error while writing", log: .protocol, type: .error)

                self.writeContinuation?.resume(throwing: error)
                self.writeContinuation = nil
            }
            return
        }

        guard self.writableState == .Connected else {
            os_log(
                "Writable is not in connected state: %@",
                log: .protocol,
                type: .default,
                (self.writableState ?? .Reading).description
            )

            self.writeContinuation?.resume(throwing: ProtocolError.Writable)
            self.writeContinuation = nil

            return
        }

        try self.writable.write(data: nextChunk)
    }

    func writable(didWrite remainingData: [UInt8], _ error: Error?) {
        if let error = error {
            os_log("Error while writing %@", log: .protocol, type: .error, error.localizedDescription)

            self.writeContinuation?.resume(throwing: error)
            self.writeContinuation = nil

            return
        }

        guard remainingData.isEmpty else {
            os_log(
                "Error while writing, data is not empty: %@",
                log: .protocol,
                type: .error,
                remainingData.description
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
            os_log("Error while writing", log: .protocol, type: .error, remainingData.description)

            self.writeContinuation?.resume(throwing: error)
            self.writeContinuation = nil
        }
    }

    func writable(didReceive data: [UInt8]?, _ error: Error?) {
        guard let receivedData = data, error == nil else {
            os_log("Error while reading %@", log: .protocol, type: .error, error.debugDescription)

            self.writeContinuation?.resume(throwing: error ?? ProtocolError.Generic)
            self.writeContinuation = nil

            return
        }

        os_log("Did receive %@", log: .protocol, type: .default, receivedData.description)

        switch receivedData {
        case ProtocolConstant.StartSequence:
            self.readBuffer = []
            os_log(
                "Read start sequence: %@, skipping",
                log: .protocol,
                type: .default,
                receivedData.description
            )

            break
        case ProtocolConstant.EndSequence:
            os_log(
                "Read end sequence: %@, closing",
                log: .protocol,
                type: .default,
                receivedData.description
            )

            do {
                try self.writable.stopReading()
            }
            catch {
                os_log(
                    "Error while stop reading %@",
                    log: .protocol,
                    type: .error,
                    error.localizedDescription
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
                os_log(
                    "Decrypted data %{private}@",
                    log: .protocol,
                    type: .default,
                    Data(decryptedDataValue).hexEncodedString
                )

                self.processCommandResponse(payload: decryptedDataValue)
            }
            else {
                throw ProtocolError.Generic
            }
        }
        catch {
            os_log(
                "Error while stop reading %@",
                log: .protocol,
                type: .error,
                error.localizedDescription
            )
            self.writeContinuation?.resume(throwing: error)
            self.writeContinuation = nil
        }
    }

    func connection(didChangeState state: WritableTLState) {
        os_log(
            "Did change status: %@ -> %@",
            log: .protocol,
            type: .default,
            self.writableState?.description ?? "nil",
            state.description
        )
        self.writableState = state
    }
}

extension ProtocolManager: ConnectableTLDelegate {
    func create(didCreate data: Any?, _ error: Error?) {
        guard error == nil else {
            os_log(
                "Creation Error %@",
                log: .protocol,
                type: .error,
                error?.localizedDescription ?? "Error not set"
            )

            self.connectionContinuation?.resume(throwing: ProtocolError.Writable)
            self.connectionContinuation = nil

            return
        }

        os_log("Writable created", log: .protocol, type: .error)
    }

    func connect(didConnect data: Any?, _ error: Error?) {
        guard error == nil else {
            os_log(
                "Connection Error %@",
                log: .protocol,
                type: .error,
                error?.localizedDescription ?? "Error not set"
            )

            self.connectionContinuation?.resume(throwing: ProtocolError.Writable)
            self.connectionContinuation = nil

            return
        }

        os_log("Writable connected", log: .protocol, type: .error)

        self.connectionContinuation?.resume()
        self.connectionContinuation = nil
    }
}

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "BundleIdentifier not set"

    fileprivate static let `protocol` = OSLog(subsystem: subsystem, category: "🔀 ProtocolManager")
}
