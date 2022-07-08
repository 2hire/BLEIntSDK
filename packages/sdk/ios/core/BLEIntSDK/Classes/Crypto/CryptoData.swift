//
//  KeyPair
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation
import K1

public typealias PrivateKey = K1.PrivateKey
public typealias PublicKey = K1.PublicKey

extension PrivateKey {
    /// Generate symmetric key between this and a PublicKey
    /// - Parameter publicKey
    /// - Returns: Symmetric key
    func symmetricKey(with publicKey: PublicKey) throws -> SymmetricKey {
        let sharedSecret = try self.sharedSecret(with: publicKey).dropFirst().dropLast(32)
        let hashedSecret = SHA256.hash(data: sharedSecret)

        return SymmetricKey(data: hashedSecret)
    }
}

private func parseNonce(data: [UInt8]) throws -> AES.GCM.Nonce {
    return try AES.GCM.Nonce.init(data: data)
}

internal struct DecryptParams {
    let privateKey: PrivateKey
    let publicKey: PublicKey

    let nonce: AES.GCM.Nonce
    let tag: [UInt8]

    init(privateKey: PrivateKey, publicKey: PublicKey, nonce: AES.GCM.Nonce, tag: [UInt8]) {
        self.publicKey = publicKey
        self.privateKey = privateKey
        self.nonce = nonce
        self.tag = tag
    }

    init(privateKey: PrivateKey, publicKey: PublicKey, nonce: [UInt8], tag: [UInt8]) throws {
        let parsedNonce = try parseNonce(data: nonce)

        self.init(privateKey: privateKey, publicKey: publicKey, nonce: parsedNonce, tag: tag)
    }
}

internal struct EncryptParams {
    let privateKey: PrivateKey
    let publicKey: PublicKey

    let nonce: AES.GCM.Nonce

    init(privateKey: PrivateKey, publicKey: PublicKey, nonce: AES.GCM.Nonce) {
        self.publicKey = publicKey
        self.privateKey = privateKey
        self.nonce = nonce
    }

    init(privateKey: PrivateKey, publicKey: PublicKey, nonce: [UInt8]) throws {
        let parsedNonce = try parseNonce(data: nonce)

        self.init(privateKey: privateKey, publicKey: publicKey, nonce: parsedNonce)
    }
}
