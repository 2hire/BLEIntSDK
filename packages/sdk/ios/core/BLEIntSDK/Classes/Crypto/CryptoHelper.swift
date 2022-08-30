//
//  CryptoHelper
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation
import K1

internal class CryptoHelper {
    private init() {}

    /// Generate a new Private and Public key pair.
    static func generatePrivateKey() throws -> PrivateKey {
        return try K1.PrivateKey.generateNew()
    }

    /// Generate a new nonce array.
    static func generateNonce(length: Int = 16) throws -> AES.GCM.Nonce {
        return try AES.GCM.Nonce(
            data: [UInt8].init(repeating: 0x00, count: length).map { x in
                UInt8.random(in: UInt8.min...UInt8.max)
            }.shuffled()
        )
    }

    /// Wrap a UInt8 array to a PublicKey
    static func wrapPublicKey(from key: [UInt8]) throws -> PublicKey {
        return try K1.PublicKey.import(from: key)
    }

    static func wrapPrivateKey(from key: [UInt8]) throws -> PrivateKey {
        return try K1.PrivateKey.import(rawRepresentation: key)
    }

    /// Decrypt data using AES.GCM
    /// - Parameters:
    ///   - cipherText: raw data to decrypted.
    ///   - data: params needed to decrypt `cipherText`.
    /// - Returns: raw [UInt8] decrypted data
    static func decrypt(cipherText: [UInt8], _ params: DecryptParams) throws -> [UInt8]? {
        let symmetricKey = try params.privateKey.symmetricKey(with: params.publicKey)

        return [UInt8](
            try CryptoKit.AES.GCM.open(
                .init(nonce: params.nonce, ciphertext: cipherText, tag: params.tag),
                using: symmetricKey
            )
        )
    }

    /// Decode data using AES.GCM and parse it to an UTF-8 string.
    /// - Parameters:
    ///   - cipherText: raw data to be decrypted.
    ///   - data: params needed to decrypt `cipherText`.
    /// - Returns: decrypted data
    static func decrypt(cipherText: [UInt8], _ params: DecryptParams) throws -> String? {
        guard let decodedMessage: [UInt8] = try decrypt(cipherText: cipherText, params) else {
            return nil
        }

        return String(bytes: decodedMessage, encoding: .utf8)
    }

    /// Encrypt an UTF-8 string using AES.GCM.
    /// - Parameters:
    ///   - message: string message to be encrypted
    ///   - encodeData: params needed to encrypt `message`.
    /// - Returns: encrypted data
    static func encrypt(message: String, _ params: EncryptParams) throws -> AES.GCM.SealedBox? {
        guard let data = message.data(using: .utf8) else {
            return nil
        }

        return try encrypt(data: [UInt8](data), params)
    }

    /// Encrypt data using AES.GCM.
    /// - Parameters:
    ///   - data: string message to be encrypted
    ///   - encodeData: params needed to encrypt `data`.
    /// - Returns: encrypted data
    static func encrypt(data: [UInt8], _ params: EncryptParams) throws -> AES.GCM.SealedBox? {
        let symmetricKey = try params.privateKey.symmetricKey(with: params.publicKey)

        return try AES.GCM.seal(data, using: symmetricKey, nonce: params.nonce)
    }
}

extension CryptoKitError {
    var description: String {
        switch self {
        case .authenticationFailure:
            return "authenticationFailure"
        case .incorrectKeySize:
            return "incorrectKeySize"
        case .incorrectParameterSize:
            return "incorrectParameterSize"
        case .unwrapFailure:
            return "unwrapFailure"
        case .wrapFailure:
            return "wrapFailure"
        default:
            return self.localizedDescription
        }
    }
}

internal class CRC32 {
    public static let DefaultPoly: UInt32 = 0x04C1_1DB7
    public static let DefaultInit: UInt32 = 0xFFFF_FFFF

    public static func checksum(with buffer: [UInt8], poly: UInt32 = DefaultPoly, initValue: UInt32 = DefaultInit)
        -> [UInt8]
    {
        return [UInt8].from(
            value: Data(buffer).withUnsafeBytes { bytes in
                return (0..<bytes.count).reduce(
                    initValue,
                    { crc, index in
                        (0...7).reduce(
                            crc ^ (UInt32(bytes[index]) << 24),
                            { a, _ in a & 0x8000_0000 != 0 ? a << 1 ^ poly : a << 1 }
                        )
                    }
                )
            }
        )
    }
}
