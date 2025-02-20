//
//  grovs.swift
//
//  grovs
//

import UIKit

/// A protocol for receiving payload from Grovs SDK.
public protocol GrovsDelegate {
    // Called when the app is opened from a deeplink
    func grovsReceivedPayloadFromDeeplink(link: String?, payload: [String: Any]?)
}

/// A class representing Grovs SDK.
public class Grovs {

    /// The delegate to receive callbacks from the SDK.
    public static var delegate: GrovsDelegate? {
        set {
            manager?.delegate = newValue
        }

        get {
            return manager?.delegate
        }
    }

    /// The API key used for linking the SDK to your account.
    private static var APIKey: String!

    /// The manager handling Grovs functionality.
    private static var manager: GrovsManager?

    // MARK: Public methods

    /// Configures the Grovs SDK with the provided API key.
    ///
    /// - Parameters:
    ///   - APIKey: The API key obtained from the web console at https://grovs.io.
    ///   - useTestEnvironment: If this is enabled the test environment will be used.
    ///   - delegate: The delegate to receive payload from the SDK.
    public static func configure(APIKey: String, useTestEnvironment: Bool, delegate: GrovsDelegate?) {
        self.APIKey = APIKey
        self.manager = GrovsManager(apiKey: APIKey, useTestEnvironment: useTestEnvironment, delegate: delegate)

        if useTestEnvironment {
            DebugLogger.shared.log(.info, "Test environment enabled.")
        }

        self.checkConfiguration()
    }

    /// Disables the Grovs SDK.
    /// - Parameter enabled: The log level to set.
    /// Default is true.
    public static func setSDK(enabled: Bool) {
        guard let manager else {
            DebugLogger.shared.log(.error, "The SDK is not configured. Setting SDK enabled won't work.")
            return
        }

        manager.setEnabled(enabled)
    }

    /// The identifier for the user.
    ///
    /// - This property allows getting and setting the user identifier.
    /// - If set to a new value, it updates the `manager`'s identifier.
    public static var userIdentifier: String? {
        set {
            guard let manager else {
                DebugLogger.shared.log(.error, "The SDK is not configured. Setting the user identifier won't work.")
                return
            }

            manager.identifier = newValue // Sets the new user identifier.
        }
        get {
            manager?.identifier // Returns the current user identifier.
        }
    }

    /// The attributes associated with the user.
    ///
    /// - This property allows getting and setting user attributes as a dictionary.
    /// - If set to a new value, it updates the `manager`'s attributes.
    public static var userAttributes: [String: Any]? {
        set {
            guard let manager else {
                DebugLogger.shared.log(.error, "The SDK is not configured. Setting user attributes won't work.")
                return
            }

            manager.attributes = newValue // Sets the new user attributes.
        }
        get {
            manager?.attributes // Returns the current user attributes.
        }
    }

    /// The push token for the user.
    ///
    /// - This property allows getting and setting the push notification token.
    /// - If set to a new value, it updates the `manager`'s push token.
    public static var pushToken: String? {
        set {
            guard let manager else {
                DebugLogger.shared.log(.error, "The SDK is not configured. Setting the push token won't work.")
                return
            }

            manager.pushToken = newValue // Sets the new push token.
        }
        get {
            manager?.pushToken // Returns the current push token.
        }
    }

    /// Sets the debug level for the SDK log messages.
    /// - Parameter level: The log level to set.
    /// Default is error.
    public static func setDebug(level: LogLevel) {
        DebugLogger.shared.logLevel = level
    }

    /// Generates a link.
    ///
    /// - Parameters:
    ///   - title: The title of the link.
    ///   - subtitle: The subtitle of the link.
    ///   - imageURL: The URL of the image associated with the link.
    ///   - data: Additional data for the link.
    ///   - tags: Tags for the link.
    ///   - completion: A closure to be executed after generating the link.
    public static func generateLink(title: String?,
                                    subtitle: String?,
                                    imageURL: String?,
                                    data: [String: Any]?,
                                    tags: [String]?,
                                    completion: @escaping GrovsURLClosure) {
        guard let manager else {
            DebugLogger.shared.log(.error, "The SDK is not configured. Links cannot be generated.")
            completion(nil)
            return
        }

        manager.generateLink(title: title, subtitle: subtitle, imageURL: imageURL, data: data, tags: tags, completion: completion)
    }

    /// Retrieves the last received payload data.
    ///
    /// - Parameter completion: A closure that takes a dictionary representing the payload data as its parameter.
    public static func lastReceivedPayload(completion: @escaping GrovsPayloadClosure) {
        guard let manager else {
            DebugLogger.shared.log(.error, "The SDK is not configured. Last received payloads won't work.")
            completion(nil)
            return
        }

        manager.getLastPayload(completion: completion)
    }

    /// Retrieves all payloads received since startup.
    ///
    /// - Parameter completion: A closure that takes an array of dictionaries, each representing a payload data, as its parameter.
    public static func allReceivedPayloadsSinceStartup(completion: @escaping GrovsPayloadsClosure) {
        guard let manager else {
            DebugLogger.shared.log(.error, "The SDK is not configured. Fetching the payloads won't work.")
            completion(nil)
            return
        }

        manager.getAllPayloadsSinceStartup(completion: completion)
    }

    // MARK: Private methods

    /// Checks the configuration validity.
    private static func checkConfiguration() {
        guard let APIKey = APIKey, APIKey.count > 0 else {
            fatalError("API Key is invalid. Make sure you've used the right value from the Web interface.")
        }

        manager?.authenticate { success in
            if !success {
                DebugLogger.shared.log(.error, "Can not initialize the SDK, the Bundle Key combo is invalid")
            } else {
                self.manager?.start()
            }
        }
    }
}

// MARK: Public scene delegate forward -- This should be called if you're using a scene delegate

extension Grovs {
    /// Handles open URL contexts for scene delegate.
    ///
    /// - Parameter URLContexts: The set of open URL contexts.
    @available(iOS 13.0, *)
    public static func handleSceneDelegate(openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // Handle URI
        manager?.handleSceneDelegate(openURLContexts: URLContexts)
    }

    /// Handles continue user activity for scene delegate.
    ///
    /// - Parameter userActivity: The user activity.
    public static func handleSceneDelegate(continue userActivity: NSUserActivity) {
        // Handle Universal Link
        manager?.handleSceneDelegate(continue: userActivity)
    }

    /// Handles options for scene delegate.
    ///
    /// - Parameter connectionOptions: The connection options.
    @available(iOS 13.0, *)
    public static func handleSceneDelegate(options connectionOptions: UIScene.ConnectionOptions) {
        // Handle both URI and Universal links
        manager?.handleSceneDelegate(connectionOptions: connectionOptions)
    }
}


// MARK: Public scene delegate forward -- This should be called if you're using a the app delegate WITHOUT Scene Delegate

extension Grovs {

    /// Handles universal link continuation for iOS 13 and later.
    ///
    /// - Parameters:
    ///   - userActivity: The user activity to continue.
    ///   - restorationHandler: A block to execute if the app is launched into the background to handle the user activity.
    /// - Returns: A Boolean value indicating whether the universal link continuation was handled successfully.
    public static func handleAppDelegate(continue userActivity: NSUserActivity,
                                         restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Handle universal link
        return manager?.handleAppDelegate(continue: userActivity, restorationHandler: restorationHandler) ?? false
    }

    /// Handles URI opening.
    ///
    /// - Parameters:
    ///   - url: The URL to open.
    ///   - options: A dictionary of URL handling options.
    /// - Returns: A Boolean value indicating whether the URI opening was handled successfully.

    public static func handleAppDelegate(open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle URI
        return manager?.handleAppDelegate(open: url, options: options) ?? false
    }
}


// MARK: Public messages

extension Grovs {
    /// Displays the messages view controller modally.
    ///
    /// - This method initializes a `UINavigationController` without a navigation bar,
    ///   sets up a `MessagesViewController`, and presents it on top of the current view hierarchy.
    public static func displayMessagesViewController(completion: GrovsEmptyClosure?) {
        guard let manager else {
            DebugLogger.shared.log(.error, "The SDK is not configured. Displaying messages won't work.")
            completion?()
            return
        }

        manager.displayMessagesViewController(completion: completion)
    }

    /// Retrieves the number of unread messages asynchronously.
    ///
    /// - Parameter completion: A closure that is called with the number of unread notifications.
    /// - The completion closure receives an optional integer value representing the count of unread notifications.
    public static func numberOfUnreadMessages(completion: @escaping GrovsIntClosure) {
        guard let manager else {
            DebugLogger.shared.log(.error, "The SDK is not configured. Number of unread messages won't work.")
            completion(nil)
            return
        }

        manager.getNumberOfUnreadNotifications(completion: completion) // Calls the manager to fetch unread notifications.
    }
}
