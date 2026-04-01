//
//  grovs.swift
//
//  grovs
//

import UIKit

/// A protocol for receiving payload from Grovs SDK.
///
/// All delegate methods are called on the **main thread**.
public protocol GrovsDelegate: AnyObject {
    /// Called when the app is opened from a deeplink.
    ///
    /// - Note: Always called on the **main thread**.
    func grovsReceivedPayloadFromDeeplink(link: String?, payload: [String: Any]?, tracking: [String: Any]?)
}

/// A class representing Grovs SDK.
public class Grovs {

    // MARK: - Thread-safe state

    /// Lock protecting access to `_manager` and `_APIKey`.
    private static let stateLock = NSLock()
    private static var _manager: GrovsManager?
    private static var _APIKey: String?

    /// Thread-safe access to the manager instance.
    private static var manager: GrovsManager? {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _manager }
        set { stateLock.lock(); defer { stateLock.unlock() }; _manager = newValue }
    }

    /// Thread-safe access to the API key.
    private static var APIKey: String? {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _APIKey }
        set { stateLock.lock(); defer { stateLock.unlock() }; _APIKey = newValue }
    }

    /// Dispatches a block to the main thread. Runs synchronously if already on main,
    /// otherwise dispatches async.
    private static func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    /// The delegate to receive callbacks from the SDK.
    ///
    /// - Important: Must be accessed on the **main thread**.
    public static var delegate: GrovsDelegate? {
        set {
            let value = newValue
            onMain {
                self.manager?.delegate = value
            }
        }

        get {
            assert(Thread.isMainThread, "Grovs.delegate must be read on the main thread")
            return manager?.delegate
        }
    }

    // MARK: Public methods

    /// Configures the Grovs SDK with the provided API key.
    ///
    /// - Parameters:
    ///   - APIKey: The API key obtained from the web console at https://grovs.io.
    ///   - useTestEnvironment: If this is enabled the test environment will be used.
    ///   - baseURL: Optional custom API domain for self-hosted backends (e.g. `https://sdk.grovs.link`). The SDK appends the API path automatically.
    ///   - delegate: The delegate to receive payload from the SDK.
    ///   - completion: Optional callback indicating whether SDK authentication succeeded or failed. Called on the **main thread**.
    public static func configure(APIKey: String, useTestEnvironment: Bool, baseURL: String? = nil, delegate: GrovsDelegate?, completion: GrovsBoolCompletion? = nil) {
        onMain {
            self.APIKey = APIKey
            self.manager = GrovsManager(apiKey: APIKey, useTestEnvironment: useTestEnvironment, baseURL: baseURL, delegate: delegate)

            if useTestEnvironment {
                DebugLogger.shared.log(.info, "Test environment enabled.")
            }

            self.checkConfiguration(completion: completion)
        }
    }

    /// Disables the Grovs SDK.
    /// - Parameter enabled: The log level to set.
    /// Default is true.
    public static func setSDK(enabled: Bool) {
        onMain {
            guard let manager else {
                DebugLogger.shared.log(.error, "The SDK is not configured. Setting SDK enabled won't work.")
                return
            }

            manager.setEnabled(enabled)
        }
    }

    /// The identifier for the user.
    ///
    /// - This property allows getting and setting the user identifier.
    /// - If set to a new value, it updates the `manager`'s identifier.
    public static var userIdentifier: String? {
        set {
            let value = newValue
            onMain {
                guard let manager else {
                    DebugLogger.shared.log(.error, "The SDK is not configured. Setting the user identifier won't work.")
                    return
                }

                manager.identifier = value
            }
        }
        get {
            manager?.identifier
        }
    }

    /// The attributes associated with the user.
    ///
    /// - This property allows getting and setting user attributes as a dictionary.
    /// - If set to a new value, it updates the `manager`'s attributes.
    public static var userAttributes: [String: Any]? {
        set {
            let value = newValue
            onMain {
                guard let manager = self.manager else {
                    DebugLogger.shared.log(.error, "The SDK is not configured. Setting user attributes won't work.")
                    return
                }

                manager.attributes = value
            }
        }
        get {
            manager?.attributes
        }
    }

    /// The push token for the user.
    ///
    /// - This property allows getting and setting the push notification token.
    /// - If set to a new value, it updates the `manager`'s push token.
    public static var pushToken: String? {
        set {
            let value = newValue
            onMain {
                guard let manager = self.manager else {
                    DebugLogger.shared.log(.error, "The SDK is not configured. Setting the push token won't work.")
                    return
                }

                manager.pushToken = value
            }
        }
        get {
            manager?.pushToken
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
    ///   - showPreviewiOS: Override the default app preview for a link for iOS.
    ///   - showPreviewAndroid: Override the default app preview for a link for Android.
    ///   - trackingCampaign: The campaign name for tracking purposes (e.g. `"BlackFriday2025"`).
    ///   - trackingSource: The traffic source (e.g. `"instagram"`, `"newsletter"`).
    ///   - trackingMedium: The medium used for the campaign (e.g. `"cpc"`, `"email"`, `"social"`).
    ///   - completion: A closure called with the generated URL, or `nil` on failure. Called on the **main thread**.
    public static func generateLink(title: String? = nil,
                                    subtitle: String? = nil,
                                    imageURL: String? = nil,
                                    data: [String: Any]? = nil,
                                    tags: [String]? = nil,
                                    customRedirects: CustomRedirects? = nil,
                                    showPreviewiOS: Bool? = nil,
                                    showPreviewAndroid: Bool? = nil,
                                    trackingCampaign: String? = nil,
                                    trackingSource: String? = nil,
                                    trackingMedium: String? = nil,
                                    completion: @escaping GrovsURLClosure) {
        onMain {
            guard let manager else {
                DebugLogger.shared.log(.error, "The SDK is not configured. Links cannot be generated.")
                completion(nil)
                return
            }

            manager.generateLink(title: title,
                                 subtitle: subtitle,
                                 imageURL: imageURL,
                                 data: data,
                                 tags: tags,
                                 customRedirects: customRedirects,
                                 showPreviewiOS: showPreviewiOS,
                                 showPreviewAndroid: showPreviewAndroid,
                                 trackingCampaign: trackingCampaign,
                                 trackingSource: trackingSource,
                                 trackingMedium: trackingMedium,
                                 completion: completion)
        }
    }

    /// Retrieves the last received payload data.
    ///
    /// - Parameter completion: A closure that takes a dictionary representing the payload data as its parameter. Called on the **main thread**.
    public static func lastReceivedPayload(completion: @escaping GrovsPayloadClosure) {
        onMain {
            guard let manager else {
                DebugLogger.shared.log(.error, "The SDK is not configured. Last received payloads won't work.")
                completion(nil)
                return
            }

            manager.getLastPayload(completion: completion)
        }
    }

    /// Retrieves all payloads received since startup.
    ///
    /// - Parameter completion: A closure that takes an array of dictionaries, each representing a payload data, as its parameter. Called on the **main thread**.
    public static func allReceivedPayloadsSinceStartup(completion: @escaping GrovsPayloadsClosure) {
        onMain {
            guard let manager else {
                DebugLogger.shared.log(.error, "The SDK is not configured. Fetching the payloads won't work.")
                completion(nil)
                return
            }

            manager.getAllPayloadsSinceStartup(completion: completion)
        }
    }

    /// Fetches details for a Grovs link generated by the SDK in the current environment.
    ///
    /// - Parameter path:
    ///   The path component of a link previously generated by the SDK (in the selected environment).
    /// - Parameter completion:
    ///   A closure that is called with a dictionary of link details on success, or `nil` if the request fails. Called on the **main thread**.
    public static func linkDetails(path: String, completion: @escaping GrovsLinkClosure) {
        onMain {
            guard let manager else {
                DebugLogger.shared.log(.error, "The SDK is not configured. Link details won't work.")
                completion(nil)
                return
            }

            manager.getLinkDetails(path: path, completion: completion)
        }
    }

    // MARK: Private methods

    /// Checks the configuration validity.
    private static func checkConfiguration(completion: GrovsBoolCompletion? = nil) {
        guard let APIKey = APIKey, APIKey.count > 0 else {
            DebugLogger.shared.log(.error, "API Key is invalid. Make sure you've used the right value from the Web interface at https://app.grovs.io.")
            self.manager = nil
            completion?(false)
            return
        }

        manager?.authenticate { success in
            if !success {
                DebugLogger.shared.log(.error, "Can not initialize the SDK, the Bundle Key combo is invalid")
            } else {
                self.manager?.start()
            }
            completion?(success)
        }
    }
}

// MARK: Public scene delegate forward -- This should be called if you're using a scene delegate

extension Grovs {
    /// Handles open URL contexts for scene delegate.
    ///
    /// - Parameter URLContexts: The set of open URL contexts.
    /// - Note: Can be called from any thread; work is dispatched to the main thread internally.
    @available(iOS 13.0, *)
    public static func handleSceneDelegate(openURLContexts URLContexts: Set<UIOpenURLContext>) {
        onMain {
            manager?.handleSceneDelegate(openURLContexts: URLContexts)
        }
    }

    /// Handles continue user activity for scene delegate.
    ///
    /// - Parameter userActivity: The user activity.
    /// - Note: Can be called from any thread; work is dispatched to the main thread internally.
    public static func handleSceneDelegate(continue userActivity: NSUserActivity) {
        onMain {
            manager?.handleSceneDelegate(continue: userActivity)
        }
    }

    /// Handles options for scene delegate.
    ///
    /// - Parameter connectionOptions: The connection options.
    /// - Note: Can be called from any thread; work is dispatched to the main thread internally.
    @available(iOS 13.0, *)
    public static func handleSceneDelegate(options connectionOptions: UIScene.ConnectionOptions) {
        onMain {
            manager?.handleSceneDelegate(connectionOptions: connectionOptions)
        }
    }
}


// MARK: Public scene delegate forward -- This should be called if you're using a the app delegate WITHOUT Scene Delegate

extension Grovs {

    /// Handles universal link continuation for iOS 13 and later.
    ///
    /// - Important: Must be called on the **main thread**.
    /// - Parameters:
    ///   - userActivity: The user activity to continue.
    ///   - restorationHandler: A block to execute if the app is launched into the background to handle the user activity.
    /// - Returns: A Boolean value indicating whether the universal link continuation was handled successfully.
    public static func handleAppDelegate(continue userActivity: NSUserActivity,
                                         restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        assert(Thread.isMainThread, "handleAppDelegate(continue:) must be called on the main thread")
        return manager?.handleAppDelegate(continue: userActivity, restorationHandler: restorationHandler) ?? false
    }

    /// Handles URI opening.
    ///
    /// - Important: Must be called on the **main thread**.
    /// - Parameters:
    ///   - url: The URL to open.
    ///   - options: A dictionary of URL handling options.
    /// - Returns: A Boolean value indicating whether the URI opening was handled successfully.
    public static func handleAppDelegate(open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        assert(Thread.isMainThread, "handleAppDelegate(open:) must be called on the main thread")
        return manager?.handleAppDelegate(open: url, options: options) ?? false
    }
}


// MARK: Public messages

extension Grovs {
    /// Displays the messages view controller modally.
    ///
    /// - This method initializes a `UINavigationController` without a navigation bar,
    ///   sets up a `MessagesViewController`, and presents it on top of the current view hierarchy.
    /// - Note: Completion is called on the **main thread**.
    public static func displayMessagesViewController(completion: GrovsEmptyClosure?) {
        onMain {
            guard let manager else {
                DebugLogger.shared.log(.error, "The SDK is not configured. Displaying messages won't work.")
                completion?()
                return
            }

            manager.displayMessagesViewController(completion: completion)
        }
    }

    /// Retrieves the number of unread messages asynchronously.
    ///
    /// - Parameter completion: A closure that is called with the number of unread notifications. Called on the **main thread**.
    public static func numberOfUnreadMessages(completion: @escaping GrovsIntClosure) {
        onMain {
            guard let manager else {
                DebugLogger.shared.log(.error, "The SDK is not configured. Number of unread messages won't work.")
                completion(nil)
                return
            }

            manager.getNumberOfUnreadNotifications(completion: completion)
        }
    }
}

extension Grovs {
    /// Logs an IAP event and sends it to the backend. This is useful for purchases made via Apple's IAP.
    ///
    /// - Parameters:
    ///   - transactionID: The StoreKit transaction identifier.
    ///   - completion: A closure called with `true` on success, `false` on failure. Called on the **main thread**.
    public static func logInAppPurchase(transactionID: UInt64, completion: @escaping GrovsBoolCompletion) {
        onMain {
            guard let manager else {
                DebugLogger.shared.log(.error, "The SDK is not configured. Sending payment events won't work.")
                completion(false)
                return
            }

            manager.logInAppPurchase(transactionID: transactionID, completion: completion)
        }
    }

    /// Logs a custom purchase transaction and sends it to the backend. This is useful for transactions that are not handled by Apple IAP.
    ///
    /// - Parameters:
    ///   - type: The type of transaction (e.g., buy, cancel).
    ///   - priceInCents: The price of the transaction in cents.
    ///   - currency: The currency of the transaction (e.g., "USD").
    ///   - productID: A product identifier (e.g. "com.acme.weather.consumable.coins.100").
    ///   - startDate: An optional start date for the transaction. Defaults to the current date if not provided.
    ///   - completion: A closure called with `true` on success, `false` on failure. Called on the **main thread**.
    public static func logCustomPurchase(type: TransactionType,
                                         priceInCents: Int,
                                         currency: String,
                                         productID: String,
                                         startDate: Date? = nil,
                                         completion: @escaping GrovsBoolCompletion) {

        onMain {
            guard let manager else {
                DebugLogger.shared.log(.error, "The SDK is not configured. Sending payment events won't work.")
                completion(false)
                return
            }

            manager.logCustomPurchase(type: type, priceInCents: priceInCents, currency: currency, productID: productID, startDate: startDate, completion: completion)
        }
    }
}
