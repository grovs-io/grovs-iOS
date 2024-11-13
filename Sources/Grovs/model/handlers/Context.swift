//
//  Context.swift
//
//  grovs
//

import Foundation

struct Context {
    // Computed property to get and set the linksquared ID from the Keychain
    static var linksquaredID: String? {
        get {
            // Retrieves the value from the Keychain
            return KeychainHelper.getValue(forKey: .linksquaredID)
        }
        set {
            // Sets or removes the value in the Keychain based on the new value
            if let newValue = newValue {
                KeychainHelper.setValue(newValue, forKey: .linksquaredID)
            } else {
                KeychainHelper.removeValue(forKey: .linksquaredID)
            }
        }
    }

    /// The identifier for the current context, used for tracking and identification.
    static var identifier: String?

    /// Attributes associated with the current context, used for providing additional context.
    static var attributes: [String: Any]?

    /// The user agent string, used for identifying the client environment.
    static var userAgent: String?

    /// A property representing the push notification token.
    static var pushToken: String?
}
