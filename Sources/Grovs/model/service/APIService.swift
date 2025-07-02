//
//  grovsService.swift
//
//  grovs
//

import Foundation

/// A typealias for a closure returning a URL.
public typealias GrovsURLClosure = (_ url: URL?) -> Void

/// A typealias for a closure returning a dictionary.
public typealias GrovsPayloadClosure = (_ dictionary: [String: Any]?) -> Void

public typealias GrovsDeviceDataClosureClosure = (_ dictionary: [String: Any]?, _ link: String?) -> Void

/// A typealias for a closure returning a array of dictionaries.
public typealias GrovsPayloadsClosure = (_ array: [[String: Any]]?) -> Void

/// A typealias for a closure returning a string.
typealias GrovsAuthenticationClosure = (_ success: Bool, _ linksquaredID: String?, _ URIScheme: String?, _ identifier: String?, _ attributes: [String: Any]?) -> Void

/// A typealias for a closure that returns an array of notifications.
typealias GrovsNotificationsClosure = (_ notifications: [Notification]?) -> Void

/// A typealias for a closure returning an int.
public typealias GrovsIntClosure = (_ value: Int?) -> Void

/// A typealias for a clsure returning a dictionary
public typealias GrovsLinkClosure = (_ dictionary: [String: Any]?) -> Void

/// A class responsible for handling API service calls.
class APIService: BaseService {

    // MARK: - Constants

    private struct Constants {
        struct URLs {
            static let endpoint = "https://sdk.sqd.link/api/v1/sdk"
//            static let endpoint = "http://sdk.lvh.me:3000/api/v1/sdk"

            static let authenticate = "/authenticate"
            static let dataForDevice = "/data_for_device"
            static let dataForDeviceAndURL = "/data_for_device_and_url"
            static let generateLink = "/create_link"
            static let event = "/event"
            static let attributes = "/visitor_attributes"

            static let notifications = "/notifications_for_device"
            static let numberOfUnreadNotifications = "/number_of_unread_notifications"
            static let markNotificationAsRead = "/mark_notification_as_read"
            static let notificationsToDisplayAutomatically = "/notifications_to_display_automatically"
            static let linkDetails = "/link_details"
        }
        struct Headers {
            static let SDKVersion = "1.4"

            static let apiKey = "PROJECT-KEY"
            static let identifier = "IDENTIFIER"
            static let platform = "PLATFORM"
            static let linksquaredID = "LINKSQUARED"
            static let SDKVersionKey = "SDK-VERSION"
        }
    }

    // MARK: - Properties

    private let apiKey: String
    private let bundleID: String
    private var accessKey: String {
        get {
            if useTestEnvironment {
                return "test_" + apiKey
            }

            return apiKey
        }
    }

    /// Indicates if the test environment should be used
    private var useTestEnvironment = false

    /// Fetch url data tasks
    private var fetchPayloadDetailsTask: URLSessionTask?
    private var fetchPayloadForURLDetailsTask: URLSessionTask?

    // MARK: - Lifecycle

    /// Initializes an `APIService` object with the provided API key and bundle ID.
    ///
    /// - Parameters:
    ///   - apiKey: The API key for authentication.
    ///   - bundleID: The bundle ID of the app.
    init(apiKey: String, bundleID: String, useTestEnvironment: Bool) {
        self.apiKey = apiKey
        self.bundleID = bundleID
        self.useTestEnvironment = useTestEnvironment
    }

    // MARK: - Public Methods

    /// Retrieves payload for app details and a URL.
    ///
    /// - Parameters:
    ///   - appDetails: Details of the app.
    ///   - url: The URL to retrieve payload for.
    ///   - completion: A closure returning the payload as a dictionary.
    func payloadFor(appDetails: AppDetails, url: String, completion: @escaping GrovsDeviceDataClosureClosure) {
        var request = urlRequestWithAuthHeaders(
            path: Constants.URLs.dataForDeviceAndURL)
        request.httpMethod = "POST"

        var body = appDetails.toBackend()
        body["url"] = url

        request.httpBody = body.dictToData()

        fetchPayloadForURLDetailsTask?.cancel()
        fetchPayloadDetailsTask?.cancel()

        DebugLogger.shared.log(.info, "Fetching payload for device and URL")
        fetchPayloadForURLDetailsTask = makeRequest(URLRequest: request) { success, json in
            guard let json = json, success else {
                DebugLogger.shared.log(.info, "Fetching payload for device and URL - No payload")
                completion(nil, nil)
                return
            }

            let data = json["data"] as? [String: Any]
            let link = json["link"] as? String

            DebugLogger.shared.log(.info, "Fetching payload for device and URL - Received payload")
            completion(data, link)
        }
    }

    /// Retrieves payload for app details.
    ///
    /// - Parameters:
    ///   - appDetails: Details of the app.
    ///   - completion: A closure returning the payload as a dictionary.
    func payloadFor(appDetails: AppDetails, completion: @escaping GrovsDeviceDataClosureClosure) {
        var request = urlRequestWithAuthHeaders(
            path: Constants.URLs.dataForDevice)
        request.httpMethod = "POST"
        request.httpBody = appDetails.toBackend().dictToData()

        DebugLogger.shared.log(.info, "Fetching payload for device")
        fetchPayloadDetailsTask?.cancel()
        fetchPayloadDetailsTask = makeRequest(URLRequest: request) { success, json in
            guard let json = json, success else {
                DebugLogger.shared.log(.info, "Fetching payload for device - No payload")
                completion(nil, nil)
                return
            }

            let data = json["data"] as? [String: Any]
            let link = json["link"] as? String

            DebugLogger.shared.log(.info, "Fetching payload for device - Received payload")
            completion(data, link)
        }
    }

    /// Generates a link.
    ///
    /// - Parameters:
    ///   - title: The title for the link.
    ///   - subtitle: The subtitle for the link.
    ///   - imageURL: The image URL for the link.
    ///   - data: Additional data for the link.
    ///   - tags: Tags to associate with the link.
    ///   - customRedirects: Override the default redirects for a link.
    ///   - showPreviewiOS: Override the default app preview for a link for iOS.
    ///   - showPreviewAndroid: Override the default app preview for a link for Android.
    ///   - completion: A closure returning the generated link as a URL.
    func generateLink(title: String?,
                      subtitle: String?,
                      imageURL: String?,
                      data: String?,
                      tags: String?,
                      customRedirects: CustomRedirects?,
                      showPreviewiOS: Bool?,
                      showPreviewAndroid: Bool?,
                      completion: @escaping GrovsURLClosure) {

        var request = urlRequestWithAuthHeaders(path: Constants.URLs.generateLink)
        request.httpMethod = "POST"
        let body = ["title": title,
                    "subtitle": subtitle,
                    "image_url": imageURL,
                    "data": data,
                    "tags": tags,
                    "ios_custom_redirect": customRedirects?.ios?.toBackend(),
                    "android_custom_redirect": customRedirects?.android?.toBackend(),
                    "desktop_custom_redirect": customRedirects?.desktop?.toBackend(),
                    "show_preview_ios": showPreviewiOS,
                    "show_preview_android": showPreviewAndroid] as [String : Any?]
        request.httpBody = body.dictToData()

        DebugLogger.shared.log(.info, "Generating link")
        makeRequest(URLRequest: request) { success, json in
            guard let json = json, success, let link = json["link"] as? String, let url = URL(string: link) else {
                DebugLogger.shared.log(.error, "Generating link FAILED")
                completion(nil)
                return
            }

            DebugLogger.shared.log(.info, "Generating link \(url.absoluteString)")
            completion(url)
        }
    }

    /// Authenticates the app.
    ///
    /// - Parameters:
    ///   - appDetails: Details of the app.
    ///   - completion: A closure returning the Linksquared ID as a string.
    func authenticate(appDetails: AppDetails, completion: @escaping GrovsAuthenticationClosure) {
        var request = urlRequestWithAuthHeaders(
            path: Constants.URLs.authenticate)
        request.httpMethod = "POST"
        request.httpBody = appDetails.toBackend().dictToData()

        DebugLogger.shared.log(.info, "Authenticate")
        makeRequest(URLRequest: request) { success, json in
            guard let json = json, success,
                    let id = json["linksquared"] as? String,
                    let uriScheme = json["uri_scheme"] as? String else {

                DebugLogger.shared.log(.info, "Authenticate - No payload")
                completion(false, nil, nil, nil, nil)
                return
            }

            let identifier = json["sdk_identifier"] as? String
            let attributes = json["sdk_attributes"] as? [String: Any]

            DebugLogger.shared.log(.info, "Authenticate - Received payload")
            completion(true, id, uriScheme, identifier, attributes)
        }
    }

    /// Adds an event.
    ///
    /// - Parameters:
    ///   - event: The event to add.
    ///   - completion: A closure indicating the success or failure of the operation.
    func addEvent(event: Event, completion: @escaping GrovsBoolCompletion) {
        var request = urlRequestWithAuthHeaders(path: Constants.URLs.event)
        request.httpMethod = "POST"
        request.httpBody = event.toBackend().dictToData()

        DebugLogger.shared.log(.info, "Add event")
        makeRequest(URLRequest: request) { success, json in
            guard json != nil, success else {
                DebugLogger.shared.log(.info, "Add event - Failed")
                completion(false)
                return
            }

            DebugLogger.shared.log(.info, "Add event - Successful")
            completion(true)
        }
    }

    /// Updates the attributes associated with the current session.
    ///
    /// - Parameter completion: A closure indicating the success or failure of the operation.

    func updateAttributes(completion: @escaping GrovsBoolCompletion) {
        var request = urlRequestWithAuthHeaders(path: Constants.URLs.attributes)
        request.httpMethod = "POST"
        let body = ["sdk_identifier": Context.identifier as Any,
                    "sdk_attributes": Context.attributes as Any,
                    "push_token": Context.pushToken as Any]
        request.httpBody = body.dictToData()

        DebugLogger.shared.log(.info, "Set attributes")
        makeRequest(URLRequest: request) { success, json in
            guard json != nil, success else {
                DebugLogger.shared.log(.info, "Set attributes - Failed")
                completion(false)
                return
            }

            DebugLogger.shared.log(.info, "Set attributes - Successful")
            completion(true)
        }
    }

    /// Retrieves notifications for a specified page.
    ///
    /// - Parameters:
    ///   - page: The page number to fetch notifications for.
    ///   - completion: A closure returning an array of notifications.

    func notifications(page: Int, completion: @escaping GrovsNotificationsClosure) {
        var request = urlRequestWithAuthHeaders(
            path: Constants.URLs.notifications)
        request.httpMethod = "POST"
        request.httpBody = ["page": page].dictToData()

        DebugLogger.shared.log(.info, "Get messages")
        makeRequest(URLRequest: request) { success, json in
            guard let jsonDict = json, let jsonData = self.jsonDataFromDictionary(jsonDict), success else {
                DebugLogger.shared.log(.info, "Get messages - Failed")
                completion(nil)
                return
            }

            do {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                let response = try decoder.decode(NotificationsResponse.self, from: jsonData)

                DebugLogger.shared.log(.info, "Get messages - Successful")
                completion(response.notifications)
            } catch {
                DebugLogger.shared.log(.info, "Get messages - Failed")
                completion(nil)
            }
        }
    }

    /// Gets the number of unread notifications.
    ///
    /// - Parameter completion: A closure returning the number of unread notifications.
    func numberOfUnreadNotifications(completion: @escaping GrovsIntClosure) {
        var request = urlRequestWithAuthHeaders(
            path: Constants.URLs.numberOfUnreadNotifications)
        request.httpMethod = "GET"

        DebugLogger.shared.log(.info, "Get unread messages")
        makeRequest(URLRequest: request) { success, json in
            guard let jsonDict = json, let value = jsonDict["number_of_unread_notifications"] as? Int, success else {
                DebugLogger.shared.log(.info, "Get unread messages - Failed")
                completion(nil)
                return
            }

            DebugLogger.shared.log(.info, "Get unread messages - Success")
            completion(value)
        }
    }

    // Marks a specified notification as read.
    ///
    /// - Parameters:
    ///   - notificationID: The ID of the notification to mark as read.
    ///   - completion: A closure indicating the success or failure of the operation.
    func markNotificationAsRead(notificationID: Int, completion: @escaping GrovsBoolCompletion) {
        var request = urlRequestWithAuthHeaders(
            path: Constants.URLs.markNotificationAsRead)
        request.httpMethod = "POST"
        request.httpBody = ["id": notificationID].dictToData()

        DebugLogger.shared.log(.info, "Mark notification as read")
        makeRequest(URLRequest: request) { success, json in
            guard success else {
                DebugLogger.shared.log(.info, "Mark notification as read - Failed")
                completion(false)
                return
            }

            DebugLogger.shared.log(.info, "Mark notification as read - Success")
            completion(true)
        }
    }

    // Retrieves notifications that should be displayed automatically.
    ///
    /// - Parameter completion: A closure returning an array of notifications that should be displayed automatically.
    func notificationsToDisplayAutomatically(completion: @escaping GrovsNotificationsClosure) {
        var request = urlRequestWithAuthHeaders(
            path: Constants.URLs.notificationsToDisplayAutomatically)
        request.httpMethod = "GET"

        DebugLogger.shared.log(.info, "Notifications to display automatically")
        makeRequest(URLRequest: request) { success, json in
            guard let jsonDict = json, let jsonData = self.jsonDataFromDictionary(jsonDict), success else {
                DebugLogger.shared.log(.info, "Notifications to display automatically - Failed")
                completion(nil)
                return
            }

            do {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                let response = try decoder.decode(NotificationsResponse.self, from: jsonData)

                DebugLogger.shared.log(.info, "Notifications to display automatically - Successful")
                completion(response.notifications)
            } catch {
                DebugLogger.shared.log(.info, "Notifications to display automatically - Failed")
                completion(nil)
            }
        }
    }

    /// Fetches details for a Grovs link generated by the SDK in the current environment.
    ///
    /// - Parameter path:
    ///   The path component of a link previously generated by the SDK (in the selected environment).
    /// - Parameter completion:
    ///   A closure that is called with a dictionary of link details on success, or `nil` if the request fails.
    func linkDetails(path: String, completion: @escaping GrovsLinkClosure) {
        var request = urlRequestWithAuthHeaders(
            path: Constants.URLs.linkDetails)
        request.httpMethod = "POST"
        request.httpBody = ["path": path].dictToData()

        DebugLogger.shared.log(.info, "Link details")
        makeRequest(URLRequest: request) { success, json in
            guard let jsonDict = json, success else {
                DebugLogger.shared.log(.info, "Link details - Failed")
                completion(nil)
                return
            }

            DebugLogger.shared.log(.info, "Link details - Successful")
            completion(jsonDict)
        }
    }

    // MARK: - Private Methods

    private func jsonDataFromDictionary(_ dict: [String: Any]) -> Data? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
            return jsonData
        } catch {
            print("Error serializing JSON: \(error)")
            return nil
        }
    }

    /// Constructs a URLRequest with authentication headers.
    ///
    /// - Parameter path: The path to append to the base URL.
    /// - Returns: A URLRequest object with authentication headers set.
    private func urlRequestWithAuthHeaders(path: String) -> URLRequest {
        let endpoint = Constants.URLs.endpoint + path
        let url = URL(string: endpoint)!

        var request = URLRequest(url: url)
        request.setValue(accessKey, forHTTPHeaderField: Constants.Headers.apiKey)
        request.setValue(bundleID, forHTTPHeaderField: Constants.Headers.identifier)
        request.setValue("ios", forHTTPHeaderField: Constants.Headers.platform)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Constants.Headers.SDKVersion, forHTTPHeaderField: Constants.Headers.SDKVersionKey)
        if let userAgent = Context.userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }

        if let id = Context.linksquaredID {
            request.setValue(id, forHTTPHeaderField: Constants.Headers.linksquaredID)
        }

        return request
    }

}
