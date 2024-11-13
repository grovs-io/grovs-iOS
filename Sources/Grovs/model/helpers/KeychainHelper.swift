//
//  KeychainHelper.swift
//
//  grovs
//

import Foundation
import Security


/// An enumeration defining keys used for storing values in the keychain.
enum KeychainKeys: String {
    case linksquaredID
}

/// A utility class for storing, retrieving, and removing values from the keychain.
class KeychainHelper {

    // MARK: - Store Value

    /// Stores a string value in the keychain for the specified key.
    ///
    /// - Parameters:
    ///   - value: The value to store in the keychain.
    ///   - key: The key under which to store the value.
    /// - Returns: A Boolean value indicating whether the operation was successful.
    @discardableResult
    static func setValue(_ value: String, forKey key: KeychainKeys) -> Bool {
        if let data = value.data(using: .utf8) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key.rawValue,
                kSecValueData as String: data
            ]

            SecItemDelete(query as CFDictionary)

            let status = SecItemAdd(query as CFDictionary, nil)
            return status == errSecSuccess
        }
        return false
    }

    // MARK: - Retrieve Value

    /// Retrieves a string value from the keychain for the specified key.
    ///
    /// - Parameter key: The key for which to retrieve the value.
    /// - Returns: The string value stored in the keychain for the specified key, if available.
    static func getValue(forKey key: KeychainKeys) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        return nil
    }

    // MARK: - Remove Value

    /// Removes the value stored in the keychain for the specified key.
    ///
    /// - Parameter key: The key for which to remove the stored value.
    /// - Returns: A Boolean value indicating whether the operation was successful.
    @discardableResult
    static func removeValue(forKey key: KeychainKeys) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}
