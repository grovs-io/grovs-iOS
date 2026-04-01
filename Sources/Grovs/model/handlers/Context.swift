//
//  Context.swift
//
//  grovs
//

import Foundation

struct Context {

    private static let lock = NSLock()

    // MARK: - Backing storage

    private static var _identifier: String?
    private static var _attributes: [String: Any]?
    private static var _userAgent: String?
    private static var _pushToken: String?

    // MARK: - Keychain-backed (thread-safe at the OS level)

    static var linksquaredID: String? {
        get {
            return KeychainHelper.getValue(forKey: .linksquaredID)
        }
        set {
            if let newValue = newValue {
                KeychainHelper.setValue(newValue, forKey: .linksquaredID)
            } else {
                KeychainHelper.removeValue(forKey: .linksquaredID)
            }
        }
    }

    // MARK: - Synchronized properties

    static var identifier: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _identifier
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _identifier = newValue
        }
    }

    static var attributes: [String: Any]? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _attributes
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _attributes = newValue
        }
    }

    static var userAgent: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _userAgent
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _userAgent = newValue
        }
    }

    static var pushToken: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _pushToken
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _pushToken = newValue
        }
    }

    /// Resets all static state. Used by tests to prevent cross-test contamination.
    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        _identifier = nil
        _attributes = nil
        _userAgent = nil
        _pushToken = nil
    }
}
