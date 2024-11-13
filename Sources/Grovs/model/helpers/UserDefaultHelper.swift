//
//  UserDefaultHelper.swift
//
//  grovs
//

import Foundation
/// An enumeration defining keys used for storing values in UserDefaults.
enum UserDefaultsKeys: String {
    case grovsNumberOfOpens
    case grovsResignTimestamp
    case grovsLastStartTimestamp
}

/// A helper class for storing, retrieving, and removing values from UserDefaults.
@objc
class UserDefaultsHelper: NSObject {

    // MARK: - Properties

    /// The UserDefaults instance used for storing values.
    private static let userDefaultsGroup: UserDefaults = UserDefaults.standard

    // MARK: - String Values

    /// Sets a string value in UserDefaults for the specified key.
    ///
    /// - Parameters:
    ///   - string: The string value to store.
    ///   - key: The key under which to store the value.
    static func set(string: String, key: UserDefaultsKeys) {
        userDefaultsGroup.setValue(string, forKey: key.rawValue)
        userDefaultsGroup.synchronize()
    }

    /// Retrieves a string value from UserDefaults for the specified key.
    ///
    /// - Parameter key: The key for which to retrieve the value.
    /// - Returns: The string value stored in UserDefaults for the specified key, if available.
    static func getString(key: UserDefaultsKeys) -> String? {
        return userDefaultsGroup.string(forKey: key.rawValue)
    }

    // MARK: - Boolean Values

    /// Sets a boolean value in UserDefaults for the specified key.
    ///
    /// - Parameters:
    ///   - boolean: The boolean value to store.
    ///   - key: The key under which to store the value.
    static func set(boolean: Bool, key: UserDefaultsKeys) {
        userDefaultsGroup.set(boolean, forKey: key.rawValue)
        userDefaultsGroup.synchronize()
    }

    /// Retrieves a boolean value from UserDefaults for the specified key.
    ///
    /// - Parameter key: The key for which to retrieve the value.
    /// - Returns: The boolean value stored in UserDefaults for the specified key.
    static func getBoolean(key: UserDefaultsKeys) -> Bool {
        return userDefaultsGroup.bool(forKey: key.rawValue)
    }

    // MARK: - Integer Values

    /// Sets an integer value in UserDefaults for the specified key.
    ///
    /// - Parameters:
    ///   - value: The integer value to store.
    ///   - key: The key under which to store the value.
    static func set(value: Int, key: UserDefaultsKeys) {
        userDefaultsGroup.set(value, forKey: key.rawValue)
        userDefaultsGroup.synchronize()
    }

    /// Retrieves an integer value from UserDefaults for the specified key.
    ///
    /// - Parameter key: The key for which to retrieve the value.
    /// - Returns: The integer value stored in UserDefaults for the specified key.
    static func getInt(key: UserDefaultsKeys) -> Int {
        return userDefaultsGroup.integer(forKey: key.rawValue)
    }

    // MARK: - Array Values

    /// Sets an array of strings in UserDefaults for the specified key.
    ///
    /// - Parameters:
    ///   - array: The array of strings to store.
    ///   - key: The key under which to store the value.
    static func set(array: [String], key: UserDefaultsKeys) {
        userDefaultsGroup.setValue(array, forKey: key.rawValue)
        userDefaultsGroup.synchronize()
    }

    /// Retrieves an array of strings from UserDefaults for the specified key.
    ///
    /// - Parameter key: The key for which to retrieve the value.
    /// - Returns: The array of strings stored in UserDefaults for the specified key, if available.
    static func getStringArray(key: UserDefaultsKeys) -> [String]? {
        return userDefaultsGroup.stringArray(forKey: key.rawValue)
    }

    // MARK: - Containment Check and Removal

    /// Checks if UserDefaults contains an item for the specified key.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: A Boolean value indicating whether UserDefaults contains an item for the specified key.
    static func containsItem(for key: UserDefaultsKeys) -> Bool {
        return userDefaultsGroup.object(forKey: key.rawValue) != nil
    }

    /// Removes the value stored in UserDefaults for the specified key.
    ///
    /// - Parameter key: The key for which to remove the stored value.
    static func remove(key: UserDefaultsKeys) {
        userDefaultsGroup.removeObject(forKey: key.rawValue)
        userDefaultsGroup.synchronize()
    }
}
