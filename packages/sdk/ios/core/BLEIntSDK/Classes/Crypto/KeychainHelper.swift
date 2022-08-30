//
//  KeychainHelper
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation
import Logging
import os.log

internal var BundleIdentifier =
    Bundle.main.bundleIdentifier ?? Bundle(for: KeychainHelper.self).bundleIdentifier

private struct KeychainResult {
    let privateKey: PrivateKey
    let timestamp: Double
}

internal class KeychainHelper {

    private static let logger = LoggingUtil.logger

    private static var bundleIdentifier: String {
        get throws {
            guard let identifier = BundleIdentifier else {
                throw KeyChainHelperError.BundleIdentifierNotSetError
            }

            return identifier
        }
    }

    private static func saveOrUpdatePrivateKeyToKeychain(_ key: KeychainResult) throws {
        var timestamp = key.timestamp
        let valueData =
            Data(bytes: &timestamp, count: MemoryLayout<Double>.size)
            + Data(key.privateKey.rawRepresentation())

        let saveQuery =
            [
                kSecAttrService: try Self.bundleIdentifier,
                kSecAttrAccount: "key",
                kSecClass: kSecClassGenericPassword,
                kSecValueData: valueData,
            ] as CFDictionary

        Self.logger.info("Saving PrivateKey in keychain", metadata: .keychain)
        let saveStatus = SecItemAdd(saveQuery, nil)

        if saveStatus == errSecDuplicateItem {
            let updateQuery =
                [
                    kSecAttrService: try Self.bundleIdentifier,
                    kSecAttrAccount: "key",
                    kSecClass: kSecClassGenericPassword,
                ] as CFDictionary

            let attributeToUpdate = [kSecValueData: valueData] as CFDictionary

            Self.logger.info("PrivateKey already in keychain, updating", metadata: .keychain)
            let updateStatus = SecItemUpdate(updateQuery, attributeToUpdate)

            guard updateStatus == errSecSuccess else {
                Self.logger.error(
                    "Error while updating PrivateKey (\(updateStatus))",
                    metadata: .keychain
                )
                throw KeyChainHelperError.GenericError
            }

            return
        }

        guard saveStatus == errSecSuccess else {
            Self.logger.error(
                "Error while saving PrivateKey (\(saveStatus))",
                metadata: .keychain
            )
            throw KeyChainHelperError.GenericError
        }
    }

    private static func getPrivateKeyFromKeychain() throws -> KeychainResult {
        var itemCopy: AnyObject?

        let query =
            [
                kSecAttrService: try Self.bundleIdentifier,
                kSecAttrAccount: "key",
                kSecClass: kSecClassGenericPassword,
                kSecMatchLimit: kSecMatchLimitOne,
                kSecReturnData: true,
            ] as CFDictionary

        let status = SecItemCopyMatching(query, &itemCopy)

        guard let keychainData = itemCopy as? Data else {
            throw KeyChainHelperError.GenericError
        }

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                Self.logger.info("PrivateKey not found in keychain", metadata: .keychain)
                throw KeyChainHelperError.PrivateKeyNotFoundError
            }
            else {
                Self.logger.error("Error while getting PrivateKey (\(status))", metadata: .keychain)
            }

            throw KeyChainHelperError.GenericError
        }

        let size = MemoryLayout<Double>.size
        let timestamp = keychainData[...(size + 1)]
        let privateKeyData = keychainData[size...]

        let privateKey = try CryptoHelper.wrapPrivateKey(from: [UInt8](privateKeyData))
        Self.logger.info("PrivateKey found in keychain", metadata: .keychain)

        return .init(
            privateKey: privateKey,
            timestamp: timestamp.withUnsafeBytes { $0.load(as: Double.self) }
        )
    }

    static func deletePrivateKey() throws {
        let query =
            [
                kSecAttrService: try Self.bundleIdentifier,
                kSecAttrAccount: "key",
                kSecClass: kSecClassGenericPassword,
            ] as CFDictionary

        let status = SecItemDelete(query)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                Self.logger.info("PrivateKey not found in keychain", metadata: .keychain)
                return
            }

            Self.logger.error("Error while deleting PrivateKey (\(status))", metadata: .keychain)
            throw KeyChainHelperError.GenericError
        }

        Self.logger.info("PrivateKey deleted from keychain", metadata: .keychain)
    }

    static func generateAndSavePrivateKey() throws -> PrivateKey {
        Self.logger.info("Generating PrivateKey", metadata: .keychain)

        let key = try CryptoHelper.generatePrivateKey()
        let result = KeychainResult.init(privateKey: key, timestamp: Date().timeIntervalSince1970)

        try Self.saveOrUpdatePrivateKeyToKeychain(result)

        return result.privateKey
    }

    static func getOrGeneratePrivateKey(with maxAge: Double? = nil) throws -> PrivateKey {
        do {
            let result = try Self.getPrivateKeyFromKeychain()

            if let keyAge = maxAge {
                let now = Date().timeIntervalSince1970

                Self.logger.debug(
                    "Key was created at \(result.timestamp) (now: \(now)) with maxAge of \(keyAge)",
                    metadata: .keychain
                )

                if result.timestamp + keyAge < now {
                    Self.logger.info("Key has expired, generating a new one", metadata: .keychain)

                    return try Self.generateAndSavePrivateKey()
                }
                else {
                    Self.logger.info("Key is still valid", metadata: .keychain)
                }
            }

            return result.privateKey
        }
        catch KeyChainHelperError.PrivateKeyNotFoundError, KeyChainHelperError.GenericError {
            return try Self.generateAndSavePrivateKey()
        }
    }
}

internal enum KeyChainHelperError: Error {
    case BundleIdentifierNotSetError
    case PrivateKeyNotFoundError
    case GenericError
}

extension Logging.Logger.Metadata {
    fileprivate static var keychain: Self {
        var metadata: Self = ["category": "🔐 KeychainHelper"]

        if let requestId = Self.requestId {
            metadata["requestId"] = "\(requestId)"
        }

        return metadata
    }
}
