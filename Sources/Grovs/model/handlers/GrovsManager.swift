//
//  grovsManager.swift
//
//  grovs
//

import Foundation
import UIKit

/// A closure used for completion handlers returning boolean values.
typealias GrovsBoolCompletion = (_ value: Bool) -> Void

/// A manager class responsible for integrating the Grovs SDK into the application.
class GrovsManager {

    // MARK: - Constants

    private struct Constants {
        static let deviceIDKey = "linkdsquare_device_id"
    }

    // MARK: - Properties

    /// The API service instance responsible for communication with the Grovs backend.
    private var apiService: APIService

    /// The API key used for authenticating requests to the Grovs backend.
    private let apiKey: String

    /// The bundle ID of the application.
    private let bundleID: String

    /// A flag indicating whether the Grovs SDK is enabled.
    private var enabled = true

    /// A flag indicating whether the user is authenticated with the Grovs backend.
    private var authenticated = false {
        didSet {
            handleActions()
        }
    }

    /// The URL to handle, used when the user is not authenticated yet.
    private var urlToHandle: String?

    /// The handler for various events related to Grovs events.
    private let eventsHandler: EventsHandler

    /// Stores the payloads received since the startup
    private var receivedPayloads = [[String: Any]]()

    /// Stores weather the app or scene delegates were called
    private var handledAppOrSceneDelegates = false {
        didSet {
            self.eventsHandler.handledAppOrSceneDelegates = handledAppOrSceneDelegates
        }
    }

    /// Closures to be called for the last payload
    private var lastPayloadClosureArray = [GrovsPayloadClosure]()

    /// Closures to be called for the payloads
    private var payloadsClosureArray = [GrovsPayloadsClosure]()

    /// Stores if attributes needs to be updated after auth
    private var shouldUpdateAttributes = false

    /// The delegate for the GrovsManager, allowing customization and handling of Grovs events.
    var delegate: GrovsDelegate?

    /// The identifier for the current user, normally a userID. This will be visible in the Grovs dashboard.
    var identifier: String? {
        set {
            Context.identifier = newValue
            updateAttributesIfNeeded()
        }
        get {
            Context.identifier
        }
    }

    /// The attributes for the current user. This will be visible in the Grovs dashboard.
    var attributes: [String: Any]? {
        set {
            Context.attributes = newValue
            updateAttributesIfNeeded()
        }
        get {
            Context.attributes
        }
    }

    /// A property representing the push notification token.
    ///
    /// This token is used for identifying the device to receive push notifications.
    var pushToken: String? {
        set {
            Context.pushToken = newValue
            updateAttributesIfNeeded()
        }
        
        get {
            Context.pushToken
        }
    }

    private let notificationsDisplayDispatchGroup = DispatchGroup()
    private var displayedNotificationsIds = [Int]()
    private var actions = [GrovsAction]()

    // MARK: - Initialization

    /// Initializes the GrovsManager with the provided API key and delegate.
    ///
    /// - Parameters:
    ///   - apiKey: The API key for authentication with the Grovs backend.
    ///   - useTestEnvironment: If the test environment should be used
    ///   - delegate: The delegate for the GrovsManager.
    init(apiKey: String, useTestEnvironment: Bool, delegate: GrovsDelegate?) {
        self.apiKey = apiKey
        self.bundleID = AppDetailsHelper.getBundleID()
        self.delegate = delegate
        self.apiService = APIService(apiKey: apiKey, bundleID: self.bundleID, useTestEnvironment: useTestEnvironment)
        self.eventsHandler = EventsHandler(apiService: self.apiService)

        addObservers()
    }

    // MARK: - Public Methods

    /// Enables or disables the Grovs SDK.
    ///
    /// - Parameter enabled: A flag indicating whether the SDK should be enabled.
    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        DebugLogger.shared.log(.info, "SDK setEnabled to: \(enabled)")
    }

    /// Starts the GrovsManager.
    func start() {
        // Implementation for starting the GrovsManager, if needed.
    }

    /// Generates a link with the provided parameters.
    ///
    /// - Parameters:
    ///   - title: The title of the link.
    ///   - subtitle: The subtitle of the link.
    ///   - imageURL: The URL of the image associated with the link.
    ///   - data: Additional data to include in the link.
    ///   - tags: Tags for the link.
    ///   - showPreviewiOS: Override the default app preview for a link for iOS.
    ///   - showPreviewAndroid: Override the default app preview for a link for Android.
    ///   - completion: A closure to be called upon completion of link generation.
    func generateLink(title: String?,
                      subtitle: String?,
                      imageURL: String?,
                      data: [String: Any]?,
                      tags: [String]?,
                      customRedirects: CustomRedirects?,
                      showPreviewiOS: Bool?,
                      showPreviewAndroid: Bool?,
                      completion: @escaping GrovsURLClosure) {
        guard enabled else {
            DebugLogger.shared.log(.error, "The SDK is not enabled. Links cannot be generated.")
            completion(nil)
            return
        }

        guard authenticated else {
            let action = GrovsAction(mainBlock: {
                self.generateLink(title: title,
                                  subtitle: subtitle,
                                  imageURL: imageURL,
                                  data: data,
                                  tags: tags,
                                  customRedirects: customRedirects,
                                  showPreviewiOS: showPreviewiOS,
                                  showPreviewAndroid: showPreviewAndroid,
                                  completion: completion)
            }, failureBlock: {
                completion(nil)
            })
            actions.append(action)

            return
        }

        do {
            var jsonString: String?
            if let data = data {
                let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                jsonString = String(data: jsonData, encoding: .utf8)
            }

            var tagsString: String?
            if let tags = tags {
                let jsonData = try JSONSerialization.data(withJSONObject: tags, options: .prettyPrinted)
                tagsString = String(data: jsonData, encoding: .utf8)
            }

            apiService.generateLink(title: title,
                                    subtitle: subtitle,
                                    imageURL: imageURL,
                                    data: jsonString,
                                    tags: tagsString,
                                    customRedirects: customRedirects,
                                    showPreviewiOS: showPreviewiOS,
                                    showPreviewAndroid: showPreviewAndroid,
                                    completion: completion)
            return
        } catch {
            DebugLogger.shared.log(.error, "Failed to convert data to JSON: \(error.localizedDescription)")
        }

        completion(nil)
    }

    /// Adds a closure to receive the last payload data.
    ///
    /// This method appends the provided closure to an array of closures that will be invoked when the last payload data is received. It then checks if payloads have been received and invokes the appropriate handler to process them.
    ///
    /// - Parameter completion: A closure that takes a dictionary representing the payload data as its parameter.
    func getLastPayload(completion: @escaping GrovsPayloadClosure) {
        lastPayloadClosureArray.append(completion)

        handlePayloadsReceivedIfNeeded()
    }

    /// Adds a closure to receive all payloads received since startup.
    ///
    /// This method appends the provided closure to an array of closures that will be invoked when all payloads received since startup are available. It then checks if payloads have been received and invokes the appropriate handler to process them.
    ///
    /// - Parameter completion: A closure that takes an array of dictionaries, each representing a payload data, as its parameter.
    func getAllPayloadsSinceStartup(completion: @escaping GrovsPayloadsClosure) {
        payloadsClosureArray.append(completion)

        handlePayloadsReceivedIfNeeded()
    }

    /// Authenticates the user with the Grovs backend.
    ///
    /// - Parameter completion: A closure called upon completion of authentication, providing a boolean value indicating success.
    func authenticate(completion: @escaping GrovsBoolCompletion) {
        guard hasURISchemesConfigured() else {
            DebugLogger.shared.log(.error, "URI schemes are not configured. Deeplinking won't work!")
            completion(false)
            return
        }

        // Fetch the user agent
        handleUserAgent {
            // Handle app details
            self.apiService.authenticate(appDetails: AppDetailsHelper.getAppDetails()) { success, linksquaredID, uriScheme, identifier, attributes in
                guard let linksquaredID = linksquaredID, let uriScheme = uriScheme, success else {
                    self.authenticated = false
                    completion(false)

                    return
                }

                Context.linksquaredID = linksquaredID

                // Update context attributes if needed
                if !self.shouldUpdateAttributes {
                    Context.identifier = identifier
                    Context.attributes = attributes
                }

                self.authenticated = true

                self.checkIfURISchemeProperlySet(uriScheme: uriScheme)
                self.handleURLIfNeeded()
                self.getDataForDevice()
                self.updateAttributesIfNeeded()

                completion(true)
            }
        }
    }
    /// Retrieves notifications for a specified page.
    ///
    /// - Parameters:
    ///   - page: The page number of notifications to retrieve. This allows for pagination of notifications.
    ///   - completion: A closure that will be called with an array of notifications when the request completes.
    func getNotifications(page: Int, completion: @escaping GrovsNotificationsClosure) {
        guard authenticated else {
            let action = GrovsAction(mainBlock: {
                self.getNotifications(page: page, completion: completion)
            }, failureBlock: {
                completion(nil)
            })
            actions.append(action)

            return
        }

        apiService.notifications(page: page, completion: completion) // Delegates the call to the API service.
    }

    /// Retrieves the number of unread notifications.
    ///
    /// - Parameter completion: A closure that will be called with the count of unread notifications, or `nil` if the request fails.
    func getNumberOfUnreadNotifications(completion: @escaping GrovsIntClosure) {
        guard authenticated else {
            let action = GrovsAction(mainBlock: {
                self.getNumberOfUnreadNotifications(completion: completion)
            }, failureBlock: {
                completion(nil)
            })
            actions.append(action)

            return
        }

        apiService.numberOfUnreadNotifications(completion: completion) // Delegates the call to the API service.
    }

    /// Displays the messages view controller modally.
    ///
    /// - This method initializes a `UINavigationController` without a navigation bar,
    ///   sets up a `MessagesViewController`, and presents it on top of the current view hierarchy.
    func displayMessagesViewController(completion: GrovsEmptyClosure?) {
        guard authenticated else {
            let action = GrovsAction(mainBlock: {
                self.displayMessagesViewController(completion: completion)
            }, failureBlock: {
                completion?()
            })
            actions.append(action)

            return
        }

        let nav = UINavigationController() // Creates a new navigation controller.
        nav.navigationBar.isHidden = true // Hides the navigation bar for the messages view.

        if let vc = MessagesViewController.loadVCFromNib()  { // Initializes the messages view controller.
            vc.manager = self // Assigns the manager to the view controller for handling notifications.
            vc.dismissalDelegate = DismissalDelegate.shared

            nav.viewControllers = [vc] // Sets the messages view controller as the root of the navigation controller.
            nav.presentationController?.delegate = DismissalDelegate.shared
            DismissalDelegate.shared.completion = completion

            Presenter.presentOnTop(nav) // Presents the navigation controller on top of the current view.
        }
    }

    /// Marks a specific notification as read.
    ///
    /// - Parameters:
    ///   - notificationID: The unique identifier of the notification to mark as read.
    ///   - completion: A closure that will be called with a boolean indicating the success or failure of the operation.
    func markNotificationAsRead(notificationID: Int, completion: @escaping GrovsBoolCompletion) {
        guard authenticated else {
            let action = GrovsAction(mainBlock: {
                self.markNotificationAsRead(notificationID: notificationID, completion: completion)
            }, failureBlock: {
                completion(false)
            })
            actions.append(action)

            return
        }

        apiService.markNotificationAsRead(notificationID: notificationID, completion: completion) // Delegates the call to the API service.
    }

    /// Fetches details for a Grovs link generated by the SDK in the current environment.
    ///
    /// - Parameter path:
    ///   The path component of a link previously generated by the SDK (in the selected environment).
    /// - Parameter completion:
    ///   A closure that is called with a dictionary of link details on success, or `nil` if the request fails.
    func getLinkDetails(path: String, completion: @escaping GrovsLinkClosure) {
        guard authenticated else {
            let action = GrovsAction(mainBlock: {
                self.getLinkDetails(path: path, completion: completion)
            }, failureBlock: {
                completion(nil)
            })
            actions.append(action)

            return
        }

        apiService.linkDetails(path: path, completion: completion)
    }


    // MARK: - App Lifecycle

    /// Called when the application becomes active.
    @objc func applicationDidBecomeActive() {
        getDataForDevice()
    }

    @objc func applicationWillResignActive() {
        // Implementation for handling application resigning active state, if needed.
    }

    // MARK: - Private Methods

    private func updateAttributesIfNeeded() {
        if !authenticated {
            shouldUpdateAttributes = true
            return
        }

        apiService.updateAttributes { value in
            if value {
                self.shouldUpdateAttributes = false
            }
        }
    }

    private func handleUserAgent(completion: @escaping GrovsEmptyClosure) {
        UserAgentHelper.getSafariUserAgent { userAgent in
            Context.userAgent = userAgent
            completion()
        }
    }

    private func handlePayloadsReceivedIfNeeded() {
        guard authenticated, handledAppOrSceneDelegates else {
            return
        }

        DispatchQueue.main.async {
            self.payloadsClosureArray.forEach { closure in
                closure(self.receivedPayloads)
            }
            self.payloadsClosureArray.removeAll()

            self.lastPayloadClosureArray.forEach { closure in
                closure(self.receivedPayloads.last)
            }
            self.lastPayloadClosureArray.removeAll()
        }
    }

    private func handleURLIfNeeded() {
        if let urlToHandle = urlToHandle {
            handleURL(url: urlToHandle)
        }
    }

    private func addObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
    }

    private func getDataForDevice() {
        guard enabled, authenticated else {
            return
        }

        self.apiService.payloadFor(appDetails: AppDetailsHelper.getAppDetails()) { payload, link in
            self.eventsHandler.setLinkToNewFutureActions(link: link, completion: {
                self.displayAutomaticNotificationsIfNeeded()
            })

            self.handleReceivedAction(link: link, payload: payload)
        }
    }

    private func handleURL(url: String) {
        guard enabled else {
            return
        }

        if !authenticated {
            urlToHandle = url
            return
        }

        self.apiService.payloadFor(appDetails: AppDetailsHelper.getAppDetails(), url: url) { payload, link in
            self.eventsHandler.setLinkToNewFutureActions(link: link, completion: nil)
            self.handleReceivedAction(link: link, payload: payload)
        }
    }

    private func handleReceivedAction(link: String?, payload: [String: Any]?) {
        if let payload = payload {
            receivedPayloads.append(payload)
        }

        if link != nil || payload != nil {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.grovsReceivedPayloadFromDeeplink(link: link, payload: payload)
            }
        }

        handlePayloadsReceivedIfNeeded()
    }

    private func displayAutomaticNotificationsIfNeeded() {
        apiService.notificationsToDisplayAutomatically { notifications in
            guard let notifications = notifications else {
                return
            }

            self.automaticallyDisplayNotifications(notifications: notifications)
        }
    }

    private func automaticallyDisplayNotifications(notifications: [Notification]) {
        // Process each notification one by one
        DispatchQueue.global(qos: .background).async {
            for notification in notifications {
                self.notificationsDisplayDispatchGroup.enter()

                // Display each notification sequentially
                self.displayNotification(notification: notification) {
                    self.notificationsDisplayDispatchGroup.leave() // Leave the group once the notification is displayed
                }

                self.notificationsDisplayDispatchGroup.wait()
            }
        }
    }

    private func displayNotification(notification: Notification, completion: @escaping GrovsEmptyClosure) {
        // Ensure that the presentation happens on the main thread
        DispatchQueue.main.async {
            if (self.displayedNotificationsIds.first(where: {$0 == notification.id}) != nil) {
                // Already displayed
                completion()
                return
            }

            if let vc = MessageDetailsViewController.loadVCFromNib() {
                vc.notification = notification
                vc.manager = self

                // Present the notification view controller on top
                Presenter.presentOnTop(vc, animated: false) {
                    self.displayedNotificationsIds.append(notification.id)
                    // Call the completion handler after the presentation is done
                    completion()
                }
            }
        }
    }

    private func handleActions() {
        for action in actions {
            if authenticated {
                action.mainBlock()
            } else {
                action.failureBlock()
            }
        }

        actions.removeAll()
    }
}

// MARK: - Scene Delegate Handler

extension GrovsManager {

    @available(iOS 13.0, *)
    func handleSceneDelegate(openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            handleURL(url: url.absoluteString)
        }

        handledAppOrSceneDelegates = true
    }

    func handleSceneDelegate(continue userActivity: NSUserActivity) {
        if let url = userActivity.webpageURL {
            handleURL(url: url.absoluteString)
        }

        handledAppOrSceneDelegates = true
    }

    @available(iOS 13.0, *)
    func handleSceneDelegate(connectionOptions: UIScene.ConnectionOptions) {
        if let url = connectionOptions.urlContexts.first?.url {
            handleURL(url: url.absoluteString)
        }

        if let url = connectionOptions.userActivities.first?.webpageURL {
            handleURL(url: url.absoluteString)
        }

        handledAppOrSceneDelegates = true
    }
}

// MARK: - App Delegate Handler

extension GrovsManager {

    func handleAppDelegate(continue userActivity: NSUserActivity,
                           restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            handleURL(url: url.absoluteString)
            handledAppOrSceneDelegates = true

            return true
        }

        handledAppOrSceneDelegates = true
        return false
    }

    func handleAppDelegate(open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        handleURL(url: url.absoluteString)
        handledAppOrSceneDelegates = true

        return true
    }
}

// MARK: - URI Schemes Configuration

extension GrovsManager {

    /// Checks if URI schemes are configured in the Info.plist.
    ///
    /// - Returns: A Boolean value indicating whether URI schemes are configured.
    func hasURISchemesConfigured() -> Bool {
        guard let urlTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] else {
            return false
        }
        return !urlTypes.isEmpty
    }

    /// Checks if a specific URI scheme is properly configured in the app's Info.plist.
    ///
    /// - Parameter uriScheme: The URI scheme to check.
    func checkIfURISchemeProperlySet(uriScheme: String) {
        // Retrieve the URL types from the Info.plist.
        guard let urlTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] else {
            return
        }

        let parsedSchema = uriScheme.replacingOccurrences(of: "://", with: "")

        // Iterate through the URL types to find the specified URI scheme.
        for urlType in urlTypes {
            if let role = urlType["CFBundleTypeRole"] as? String, let schemes = urlType["CFBundleURLSchemes"] as? [String], role == "Editor" {
                if schemes.contains(parsedSchema) {
                    // If the URI scheme is found, log success and return.
                    DebugLogger.shared.log(.info, "URL Scheme properly configured.")
                    return
                }
            }
        }

        // Log an error if the URI scheme is not properly configured.
        DebugLogger.shared.log(.error, "There's a mismatch between the URL Scheme in the project and the one from the dashboard, deeplinking won't function properly!")
    }
}
