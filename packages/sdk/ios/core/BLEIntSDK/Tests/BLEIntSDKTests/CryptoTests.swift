//
//  CryptoTests
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import CryptoKit
import XCTest

@testable import _2hire_BLEIntSDK

class CryptoTests: XCTestCase {
    private let externalPublicKey: [UInt8] = [
        2, 9, 122, 212, 205, 206, 37, 68, 136, 144, 47, 15, 146, 251, 239, 126, 41, 145, 184, 177, 65,
        43, 227, 33, 104, 118, 102, 37, 45, 91, 80, 216, 195,
    ]

    func testGeneratePrivateKey() throws {
        let privateKey = try CryptoHelper.generatePrivateKey()

        XCTAssertNotNil(privateKey)
        XCTAssertNotNil(privateKey.publicKey)

        XCTAssertEqual(try privateKey.publicKey.rawRepresentation(format: .compressed).count, 33)
    }

    func testEncryptAndDecryptWithTheSameKeyPair() throws {
        let privateKey = try CryptoHelper.generatePrivateKey()

        let nonce = AES.GCM.Nonce.init()
        let encryptParams = EncryptParams.init(
            privateKey: privateKey,
            publicKey: privateKey.publicKey,
            nonce: nonce
        )

        let encryptData = try CryptoHelper.encrypt(message: "testMessage", encryptParams)

        XCTAssertNotNil(encryptData)
        XCTAssertNotNil(encryptData?.ciphertext)
        XCTAssertNotNil(encryptData?.tag)

        let tag = [UInt8](encryptData!.tag)

        XCTAssertNotNil(tag)
        XCTAssertEqual(tag.count, 16)

        let cipherText = [UInt8](encryptData!.ciphertext)

        XCTAssertNotNil(cipherText)
        XCTAssertEqual(cipherText.count, 11)

        let decryptParams = DecryptParams.init(
            privateKey: privateKey,
            publicKey: privateKey.publicKey,
            nonce: nonce,
            tag: tag
        )

        let decryptedData: String? = try CryptoHelper.decrypt(cipherText: cipherText, decryptParams)

        XCTAssertNotNil(decryptedData)
        XCTAssertEqual(decryptedData, "testMessage")
    }

    func testWrapPublicKey() throws {
        let publicKey = try CryptoHelper.wrapPublicKey(from: externalPublicKey)

        XCTAssertNotNil(publicKey)
        XCTAssertEqual(try publicKey.rawRepresentation(format: .compressed), externalPublicKey)
    }

    func testEncryptAndDecryptWithExternalPublicKey() throws {
        let privateKey = try CryptoHelper.generatePrivateKey()

        let parsedPublicKey = try CryptoHelper.wrapPublicKey(from: externalPublicKey)

        let nonce = AES.GCM.Nonce.init()
        let encryptParams = EncryptParams.init(
            privateKey: privateKey,
            publicKey: parsedPublicKey,
            nonce: nonce
        )

        let encryptData = try CryptoHelper.encrypt(message: "testMessage", encryptParams)

        XCTAssertNotNil(encryptData)
        XCTAssertNotNil(encryptData?.ciphertext)
        XCTAssertNotNil(encryptData?.tag)

        let tag = [UInt8](encryptData!.tag)

        XCTAssertNotNil(tag)
        XCTAssertEqual(tag.count, 16)

        let cipherText = [UInt8](encryptData!.ciphertext)

        XCTAssertNotNil(cipherText)
        XCTAssertEqual(cipherText.count, 11)

        let decryptParams = DecryptParams.init(
            privateKey: privateKey,
            publicKey: parsedPublicKey,
            nonce: nonce,
            tag: tag
        )

        let decryptedData: String? = try CryptoHelper.decrypt(cipherText: cipherText, decryptParams)

        XCTAssertNotNil(decryptedData)
        XCTAssertEqual(decryptedData, "testMessage")
    }

    func testEncryptBetweenTwoActors() throws {
        let message = "Hey Bob! It's a-me Alice!"

        let aliceKey = try CryptoHelper.generatePrivateKey()
        let bobKey = try CryptoHelper.generatePrivateKey()

        let nonce = AES.GCM.Nonce()

        let encryptData = try CryptoHelper.encrypt(
            message: message,
            .init(privateKey: aliceKey, publicKey: bobKey.publicKey, nonce: nonce)
        )

        XCTAssertNotNil(encryptData)
        XCTAssertNotNil(encryptData?.ciphertext)
        XCTAssertNotNil(encryptData?.tag)

        let decryptedData: String? = try CryptoHelper.decrypt(
            cipherText: [UInt8](encryptData!.ciphertext),
            .init(
                privateKey: bobKey,
                publicKey: aliceKey.publicKey,
                nonce: nonce,
                tag: [UInt8](encryptData!.tag)
            )
        )

        XCTAssertNotNil(decryptedData)
        XCTAssertEqual(decryptedData, message)
    }

    func testEncryptBetweenTwoActorsWithWrongKeys() throws {
        let message = "Hey Bob! It's a-me Alice!"

        let aliceKey = try CryptoHelper.generatePrivateKey()
        let bobKey = try CryptoHelper.generatePrivateKey()

        let nonce = AES.GCM.Nonce()

        let encryptData = try CryptoHelper.encrypt(
            message: message,
            .init(privateKey: aliceKey, publicKey: bobKey.publicKey, nonce: nonce)
        )

        XCTAssertNotNil(encryptData)
        XCTAssertNotNil(encryptData?.ciphertext)
        XCTAssertNotNil(encryptData?.tag)

        var decryptedData: String?

        do {
            // Using Bob's public keys instead alice's
            decryptedData = try CryptoHelper.decrypt(
                cipherText: [UInt8](encryptData!.ciphertext),
                .init(
                    privateKey: bobKey,
                    publicKey: bobKey.publicKey,
                    nonce: nonce,
                    tag: [UInt8](encryptData!.tag)
                )
            )
        }
        catch {}

        XCTAssertNil(decryptedData)
    }

}
