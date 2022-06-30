//
//  KeychainHelper
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation
import os.log

internal var BundleIdentifier =
    Bundle.main.bundleIdentifier ?? Bundle(for: KeychainHelper.self).bundleIdentifier

private struct KeychainResult {
    let privateKey: PrivateKey
    let timestamp: Double
}

internal class KeychainHelper {

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

        os_log("Saving PrivateKey in keychain", log: .keychain, type: .debug)
        let saveStatus = SecItemAdd(saveQuery, nil)

        if saveStatus == errSecDuplicateItem {
            let updateQuery =
                [
                    kSecAttrService: try Self.bundleIdentifier,
                    kSecAttrAccount: "key",
                    kSecClass: kSecClassGenericPassword,
                ] as CFDictionary

            let attributeToUpdate = [kSecValueData: valueData] as CFDictionary

            os_log("PrivateKey already in keychain, updating", log: .keychain, type: .debug)
            let updateStatus = SecItemUpdate(updateQuery, attributeToUpdate)

            guard updateStatus == errSecSuccess else {
                os_log(
                    "Error while updating PrivateKey in keychain already",
                    log: .keychain,
                    type: .debug,
                    updateStatus.description
                )
                throw KeyChainHelperError.GenericError
            }

            return
        }

        guard saveStatus == errSecSuccess else {
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
                os_log("PrivateKey not found in keychain", log: .keychain, type: .debug)
                throw KeyChainHelperError.PrivateKeyNotFoundError
            }

            throw KeyChainHelperError.GenericError
        }

        let size = MemoryLayout<Double>.size
        let timestamp = keychainData[...(size + 1)]
        let privateKeyData = keychainData[size...]

        let privateKey = try CryptoHelper.wrapPrivateKey(from: [UInt8](privateKeyData))
        os_log("PrivateKey found in keychain", log: .keychain, type: .debug)

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
            throw KeyChainHelperError.GenericError
        }

        os_log("PrivateKey deleted from keychain", log: .keychain, type: .debug)
    }

    static func generateAndSavePrivateKey() throws -> PrivateKey {
        os_log("Generating PrivateKey", log: .keychain, type: .debug)

        let key = try CryptoHelper.generatePrivateKey()
        let result = KeychainResult.init(privateKey: key, timestamp: Date().timeIntervalSince1970)

        try Self.saveOrUpdatePrivateKeyToKeychain(result)

        return result.privateKey
    }

    static func getOrGeneratePrivateKey(with maxAge: Double? = nil) throws -> PrivateKey {
        do {
            let result = try Self.getPrivateKeyFromKeychain()

            if let keyAge = maxAge {
                let now = Date()

                os_log(
                    "Key was created at %@ (now: %@) with maxAge of %@",
                    log: .keychain,
                    type: .debug,
                    Date(timeIntervalSince1970: result.timestamp).description,
                    now.description,
                    keyAge.description
                )

                if result.timestamp + keyAge < now.timeIntervalSince1970 {
                    os_log("Key has expired, generating a new one", log: .keychain, type: .debug)

                    return try Self.generateAndSavePrivateKey()
                }
                else {
                    os_log("Key is still valid", log: .keychain, type: .debug)
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

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "BundleIdentifier not set"

    fileprivate static let keychain = OSLog(subsystem: subsystem, category: "🔐 KeychainHelper")
}
