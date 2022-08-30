//
//  ProtocolStructs.swift
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import CryptoKit
import Foundation

internal protocol CodableBytes {
    init(from bytes: [UInt8]) throws

    func encode() -> [UInt8]
}

internal protocol Payload: CodableBytes {
    var data: [UInt8] { get }
}

// MARK: Protocol packets

internal protocol ProtocolPacket: Payload {
    var version: UInt8 { get }
}

internal struct EncryptedCommandPacket {
    let version: UInt8
    var data: [UInt8]

    let nonce: [UInt8]
    var tag: [UInt8]

    func decrypt(
        privateKey: PrivateKey,
        publicKey: PublicKey
    ) throws -> [UInt8] {
        let decryptedPayload: [UInt8]? = try CryptoHelper.decrypt(
            cipherText: self.data,
            .init(
                privateKey: privateKey,
                publicKey: publicKey,
                nonce: AES.GCM.Nonce(data: self.nonce),
                tag: self.tag
            )
        )

        guard let decryptedPayload = decryptedPayload else {
            throw ProtocolError.Crypto
        }

        return decryptedPayload
    }

    static func encrypt(
        _ data: [UInt8],
        version: UInt8,
        privateKey: PrivateKey,
        publicKey: PublicKey
    ) throws -> EncryptedCommandPacket {
        let nonce = [UInt8](try CryptoHelper.generateNonce(length: 16))

        let sealedBox = try CryptoHelper.encrypt(
            data: data,
            .init(privateKey: privateKey, publicKey: publicKey, nonce: nonce)
        )

        guard let encryptedData = sealedBox else {
            throw ProtocolError.Crypto
        }

        let data = [UInt8](encryptedData.ciphertext)
        let tag = [UInt8](encryptedData.tag)

        return .init(version: version, data: data, nonce: nonce, tag: tag)
    }
}

extension EncryptedCommandPacket: ProtocolPacket {
    init(from bytes: [UInt8]) throws {
        let version = UInt8(bytes[0])
        let nonce = [UInt8](bytes[1...16])
        let tag = [UInt8](bytes[17...32])
        let encryptedPayload = [UInt8](bytes[33...])

        self.init(version: version, data: encryptedPayload, nonce: nonce, tag: tag)
    }

    func encode() -> [UInt8] {
        var packet = [UInt8]()

        packet.append(contentsOf: [self.version])
        packet.append(contentsOf: self.nonce)
        packet.append(contentsOf: self.tag)
        packet.append(contentsOf: self.data)

        return packet
    }
}

// MARK: Command response payload
internal struct CommandResponsePayload: Payload {
    let data: [UInt8]
    let commandIdentifier: CommandIdentifier
}

extension CommandResponsePayload {
    init(from bytes: [UInt8]) throws {
        guard let messageType = ProtocolPacketType(rawValue: bytes[0]), messageType == .Response else {
            throw ProtocolError.InvalidData("Invalid message type")
        }

        guard let commandIdentifier = CommandIdentifier(rawValue: bytes[5]) else {
            throw ProtocolError.InvalidData("Invalid command identifier")
        }

        let additionalPayload = [UInt8](bytes[6...])

        self.init(
            data: additionalPayload,
            commandIdentifier: commandIdentifier
        )
    }

    func encode() -> [UInt8] {
        var packet = [UInt8]()

        packet.append(contentsOf: [ProtocolPacketType.Response.rawValue])
        packet.append(contentsOf: Date().timestamp.prefix(4))
        packet.append(contentsOf: [commandIdentifier.rawValue])

        packet.append(contentsOf: self.data)

        return packet
    }
}

internal struct ErrorCommandPayload: CodableBytes {
    let errorCode: ProtocolErrorCode
}

extension ErrorCommandPayload {
    init(from bytes: [UInt8]) throws {
        guard let value = ProtocolErrorCode(rawValue: bytes[0]) else {
            throw ProtocolError.InvalidData("Invalid command error code")
        }

        self.init(errorCode: value)
    }

    func encode() -> [UInt8] {
        var packet = [UInt8]()

        packet.append(contentsOf: [self.errorCode.rawValue])

        return packet
    }
}

// MARK: Command request payload
internal struct CommandRequestPayload: Payload {
    let data: [UInt8]
}

extension CommandRequestPayload {
    init(from bytes: [UInt8]) throws {
        guard let messageType = ProtocolPacketType(rawValue: bytes[0]), messageType == .Request else {
            throw ProtocolError.InvalidData("Invalid message type")
        }

        let additionalPayload = [UInt8](bytes[5...])

        self.init(
            data: additionalPayload
        )
    }

    func encode() -> [UInt8] {
        var packet = [UInt8]()

        packet.append(contentsOf: [ProtocolPacketType.Request.rawValue])
        packet.append(contentsOf: Date().timestamp.prefix(4))

        packet.append(contentsOf: self.data)

        return packet
    }
}
