import XCTest
@testable import Grovs

/// A spy delegate that records calls and can fulfill an expectation on each call.
private class SpyDelegate: GrovsDelegate {
    var receivedPayloads: [(link: String?, payload: [String: Any]?, tracking: [String: Any]?)] = []

    /// When set, fulfilled every time the delegate is called.
    var payloadExpectation: XCTestExpectation?

    func grovsReceivedPayloadFromDeeplink(link: String?, payload: [String: Any]?, tracking: [String: Any]?) {
        receivedPayloads.append((link, payload, tracking))
        payloadExpectation?.fulfill()
    }
}

/// Subclass that bypasses the Bundle.main URI scheme check for testing.
private class TestableGrovsManager: GrovsManager {
    override func hasURISchemesConfigured() -> Bool {
        return true
    }
}

final class GrovsManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        BaseService.urlProtocolClasses = [MockURLProtocol.self]
        Context.reset()
    }

    override func tearDown() {
        BaseService.urlProtocolClasses = []
        MockURLProtocol.reset()
        Context.reset()
        super.tearDown()
    }

    /// Creates a standard GrovsManager with catch-all mock handlers.
    private func makeManager(delegate: GrovsDelegate? = nil) -> GrovsManager {
        setupDefaultHandlers()
        return GrovsManager(apiKey: "test-key", useTestEnvironment: true, delegate: delegate)
    }

    /// Creates a TestableGrovsManager (URI scheme check bypassed) with catch-all mock handlers.
    private func makeTestableManager(delegate: GrovsDelegate? = nil) -> TestableGrovsManager {
        setupDefaultHandlers()
        return TestableGrovsManager(apiKey: "test-key", useTestEnvironment: true, delegate: delegate)
    }

    private func setupDefaultHandlers() {
        MockURLProtocol.requestHandlers["/api/v1/sdk/event"] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: ["status": "ok"])
            return (response, data)
        }
        MockURLProtocol.requestHandlers["/api/v1/sdk/data_for_device"] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: ["status": "ok"])
            return (response, data)
        }
    }

    /// Sets up mock handlers for all endpoints triggered during authentication.
    private func setupAuthenticationHandlers(payloadData: [String: Any]? = nil) {
        MockURLProtocol.requestHandlers["/api/v1/sdk/authenticate"] = { request in
            let json: [String: Any] = [
                "linksquared": "ls-test-id",
                "uri_scheme": "testapp://",
                "sdk_identifier": "user-1",
                "sdk_attributes": ["tier": "free"]
            ]
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }
        let devicePayload = payloadData ?? ["status": "ok"]
        MockURLProtocol.requestHandlers["/api/v1/sdk/data_for_device"] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: devicePayload)
            return (response, data)
        }
        MockURLProtocol.requestHandlers["/api/v1/sdk/visitor_attributes"] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: ["status": "ok"])
            return (response, data)
        }
        MockURLProtocol.requestHandlers["/api/v1/sdk/notifications_to_display_automatically"] = { request in
            let json: [String: Any] = ["notifications": []]
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }
    }

    /// Sets up a mock handler for the /data_for_device_and_url endpoint.
    private func setupPayloadForURLHandler(data: [String: Any]? = ["screen": "promo"],
                                           link: String? = "https://app.link/xyz",
                                           tracking: [String: Any]? = ["src": "email"]) {
        var json: [String: Any] = [:]
        if let data = data { json["data"] = data }
        if let link = link { json["link"] = link }
        if let tracking = tracking { json["tracking"] = tracking }

        MockURLProtocol.requestHandlers["/api/v1/sdk/data_for_device_and_url"] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }
    }

    /// Authenticates a TestableGrovsManager and waits for completion.
    /// Returns the manager ready for further operations.
    @discardableResult
    private func authenticateAndWait(_ manager: TestableGrovsManager,
                                     file: StaticString = #filePath,
                                     line: UInt = #line) -> TestableGrovsManager {
        let exp = expectation(description: "authenticate")
        manager.authenticate { success in
            XCTAssertTrue(success, "authenticate should succeed with mocked endpoints",
                          file: file, line: line)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
        return manager
    }

    // MARK: - Identifier / Attributes / Push Token

    func testIdentifierStoresInContext() {
        let manager = makeManager()
        XCTAssertNil(manager.identifier)

        manager.identifier = "user-123"
        XCTAssertEqual(manager.identifier, "user-123")
        XCTAssertEqual(Context.identifier, "user-123")
    }

    func testAttributesStoresInContext() {
        let manager = makeManager()
        XCTAssertNil(manager.attributes)

        manager.attributes = ["plan": "pro"]
        XCTAssertEqual(manager.attributes?["plan"] as? String, "pro")
        XCTAssertEqual(Context.attributes?["plan"] as? String, "pro")
    }

    func testPushTokenStoresInContext() {
        let manager = makeManager()
        XCTAssertNil(manager.pushToken)

        manager.pushToken = "abc-token"
        XCTAssertEqual(manager.pushToken, "abc-token")
        XCTAssertEqual(Context.pushToken, "abc-token")
    }

    // MARK: - setEnabled / generateLink

    func testGenerateLinkReturnsNilWhenDisabled() {
        let manager = makeManager()
        manager.setEnabled(false)

        let exp = expectation(description: "generateLink disabled")
        manager.generateLink(title: "Test", subtitle: nil, imageURL: nil,
                             data: nil, tags: nil, customRedirects: nil,
                             showPreviewiOS: nil, showPreviewAndroid: nil) { url in
            XCTAssertNil(url, "generateLink should return nil when SDK is disabled")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)
    }

    func testGenerateLinkQueuesWhenNotAuthenticated() {
        let manager = makeManager()
        let exp = expectation(description: "completion should NOT be called")
        exp.isInverted = true

        manager.generateLink(title: "Test", subtitle: nil, imageURL: nil,
                             data: nil, tags: nil, customRedirects: nil,
                             showPreviewiOS: nil, showPreviewAndroid: nil) { _ in
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2)
    }

    // MARK: - authenticate

    func testAuthenticateFailsWithoutURISchemes() {
        let manager = makeManager()

        let exp = expectation(description: "authenticate")
        manager.authenticate { success in
            XCTAssertFalse(success, "authenticate should fail when URI schemes are not configured")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testHasURISchemesConfiguredReturnsFalseInTestBundle() {
        let manager = makeManager()
        XCTAssertFalse(manager.hasURISchemesConfigured(),
                       "Test bundle should not have CFBundleURLTypes")
    }

    // MARK: - Authenticated happy path

    func testAuthenticateSucceedsWithTestableManager() {
        let manager = makeTestableManager()
        setupAuthenticationHandlers()
        authenticateAndWait(manager)
    }

    func testAuthenticatedManagerDrainsQueuedGenerateLinkAction() {
        let manager = makeTestableManager()
        setupAuthenticationHandlers()
        MockURLProtocol.requestHandlers["/api/v1/sdk/create_link"] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: ["link": "https://grovs.link/queued"])
            return (response, data)
        }

        let linkExp = expectation(description: "queued generateLink completes")
        manager.generateLink(title: "Queued", subtitle: nil, imageURL: nil,
                             data: nil, tags: nil, customRedirects: nil,
                             showPreviewiOS: nil, showPreviewAndroid: nil) { url in
            XCTAssertEqual(url?.absoluteString, "https://grovs.link/queued",
                           "Queued action should execute after authentication")
            linkExp.fulfill()
        }

        let authExp = expectation(description: "authenticate")
        manager.authenticate { success in
            XCTAssertTrue(success)
            authExp.fulfill()
        }

        wait(for: [authExp, linkExp], timeout: 5)
    }

    func testAuthenticatedManagerReceivesPayloadViaDelegate() {
        let spy = SpyDelegate()
        let exp = expectation(description: "delegate receives payload")
        spy.payloadExpectation = exp

        let payloadData: [String: Any] = [
            "data": ["screen": "home"],
            "link": "https://test.com/deep",
            "tracking": ["src": "test"]
        ]

        let manager = makeTestableManager(delegate: spy)
        setupAuthenticationHandlers(payloadData: payloadData)
        authenticateAndWait(manager)

        wait(for: [exp], timeout: 10)

        XCTAssertFalse(spy.receivedPayloads.isEmpty,
                       "Delegate should receive payload after successful authenticate")
        if let first = spy.receivedPayloads.first {
            XCTAssertEqual(first.link, "https://test.com/deep")
            XCTAssertEqual(first.payload?["screen"] as? String, "home")
        }
    }

    // MARK: - Deep Link / URL Handling

    func testHandleAppDelegateOpenURLCallsDelegateWithPayload() {
        let spy = SpyDelegate()
        let manager = makeTestableManager(delegate: spy)
        setupAuthenticationHandlers()
        authenticateAndWait(manager)

        // Now set up the URL payload handler and wire the spy expectation
        setupPayloadForURLHandler()
        let exp = expectation(description: "delegate called with URL payload")
        spy.payloadExpectation = exp

        _ = manager.handleAppDelegate(open: URL(string: "testapp://deep/link")!, options: [:])

        wait(for: [exp], timeout: 10)

        if let urlPayload = spy.receivedPayloads.last {
            XCTAssertEqual(urlPayload.link, "https://app.link/xyz")
            XCTAssertEqual(urlPayload.payload?["screen"] as? String, "promo")
            XCTAssertEqual(urlPayload.tracking?["src"] as? String, "email")
        } else {
            XCTFail("Delegate should receive URL payload")
        }
    }

    func testHandleAppDelegateContinueUniversalLinkCallsDelegate() {
        let spy = SpyDelegate()
        let manager = makeTestableManager(delegate: spy)
        setupAuthenticationHandlers()
        authenticateAndWait(manager)

        setupPayloadForURLHandler()
        let exp = expectation(description: "delegate called via universal link")
        spy.payloadExpectation = exp

        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = URL(string: "https://app.link/xyz")

        let result = manager.handleAppDelegate(continue: activity, restorationHandler: { _ in })
        XCTAssertTrue(result, "Should return true for browsing web activity")

        wait(for: [exp], timeout: 10)
        XCTAssertEqual(spy.receivedPayloads.last?.link, "https://app.link/xyz")
    }

    func testHandleAppDelegateContinueNonBrowsingTypeReturnsFalse() {
        let manager = makeTestableManager()
        setupAuthenticationHandlers()
        authenticateAndWait(manager)

        let activity = NSUserActivity(activityType: "com.apple.other")
        let result = manager.handleAppDelegate(continue: activity, restorationHandler: { _ in })
        XCTAssertFalse(result, "Should return false for non-browsing activity type")
    }

    func testURLReceivedBeforeAuthIsProcessedAfterAuth() {
        let spy = SpyDelegate()
        let manager = makeTestableManager(delegate: spy)
        setupAuthenticationHandlers()
        setupPayloadForURLHandler()

        // Wire spy to fulfill when the URL payload arrives
        let exp = expectation(description: "URL payload received")
        exp.assertForOverFulfill = false
        spy.payloadExpectation = exp

        // Call handleAppDelegate BEFORE auth — URL should be stored for later
        _ = manager.handleAppDelegate(open: URL(string: "testapp://pending")!, options: [:])

        authenticateAndWait(manager)

        wait(for: [exp], timeout: 10)
        let hasURLPayload = spy.receivedPayloads.contains(where: { $0.link == "https://app.link/xyz" })
        XCTAssertTrue(hasURLPayload, "Pending URL should be processed after authentication")
    }

    func testHandleAppDelegateOpenURLWhenDisabledIsIgnored() {
        let spy = SpyDelegate()
        let manager = makeTestableManager(delegate: spy)
        setupAuthenticationHandlers()
        authenticateAndWait(manager)

        setupPayloadForURLHandler()
        manager.setEnabled(false)

        // Wire spy to detect any call — should NOT fire
        let exp = expectation(description: "delegate NOT called for disabled SDK")
        exp.isInverted = true
        spy.payloadExpectation = exp

        _ = manager.handleAppDelegate(open: URL(string: "testapp://disabled")!, options: [:])

        wait(for: [exp], timeout: 1)
    }

    func testSceneDelegateContinueUniversalLinkCallsDelegate() {
        let spy = SpyDelegate()
        let manager = makeTestableManager(delegate: spy)
        setupAuthenticationHandlers()
        authenticateAndWait(manager)

        setupPayloadForURLHandler()
        let exp = expectation(description: "delegate called via scene continue")
        spy.payloadExpectation = exp

        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = URL(string: "https://app.link/xyz")

        manager.handleSceneDelegate(continue: activity)

        wait(for: [exp], timeout: 10)
        XCTAssertEqual(spy.receivedPayloads.last?.link, "https://app.link/xyz")
    }

    // MARK: - Authentication Context Behavior

    func testAuthSetsContextIdentifierWhenNotManuallySet() {
        let manager = makeTestableManager()
        setupAuthenticationHandlers()
        authenticateAndWait(manager)

        XCTAssertEqual(Context.identifier, "user-1",
                       "Auth should set Context.identifier from backend response")
        XCTAssertEqual(Context.attributes?["tier"] as? String, "free",
                       "Auth should set Context.attributes from backend response")
    }

    func testAuthDoesNotOverrideManuallySetIdentifier() {
        let manager = makeTestableManager()
        setupAuthenticationHandlers()

        manager.identifier = "my-id"

        authenticateAndWait(manager)

        XCTAssertEqual(Context.identifier, "my-id",
                       "Auth should not override manually set identifier")
    }

    func testAutoNotificationFetchTriggeredAfterAuth() {
        let pathExp = expectation(description: "notification path requested")
        pathExp.assertForOverFulfill = false
        MockURLProtocol.pathExpectations["/api/v1/sdk/notifications_to_display_automatically"] = pathExp

        let manager = makeTestableManager()
        setupAuthenticationHandlers()
        authenticateAndWait(manager)

        wait(for: [pathExp], timeout: 10)
        XCTAssertTrue(MockURLProtocol.requestedPaths.contains("/api/v1/sdk/notifications_to_display_automatically"))
    }

    // MARK: - Edge Cases

    func testPayloadWithNilDataAndNilLinkDoesNotCallDelegate() {
        let spy = SpyDelegate()
        let manager = makeTestableManager(delegate: spy)
        setupAuthenticationHandlers(payloadData: ["status": "ok"])
        authenticateAndWait(manager)

        // URL handler returns empty payload (no data/link/tracking)
        MockURLProtocol.requestHandlers["/api/v1/sdk/data_for_device_and_url"] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: [:])
            return (response, data)
        }

        // Wire spy — should NOT fire because both link and payload are nil
        let exp = expectation(description: "delegate NOT called for empty payload")
        exp.isInverted = true
        spy.payloadExpectation = exp

        _ = manager.handleAppDelegate(open: URL(string: "testapp://empty")!, options: [:])

        wait(for: [exp], timeout: 1)
    }

    func testQueuedActionsFireAfterRetryingAuth() {
        let manager = makeTestableManager()
        setupDefaultHandlers()

        // First auth fails
        MockURLProtocol.requestHandlers["/api/v1/sdk/authenticate"] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }

        let failExp = expectation(description: "first auth fails")
        manager.authenticate { success in
            XCTAssertFalse(success, "First auth should fail")
            failExp.fulfill()
        }
        wait(for: [failExp], timeout: 5)

        // Queue generateLink AFTER first auth fails
        let linkExp = expectation(description: "queued generateLink fires after retry")
        manager.generateLink(title: "Retry", subtitle: nil, imageURL: nil,
                             data: nil, tags: nil, customRedirects: nil,
                             showPreviewiOS: nil, showPreviewAndroid: nil) { url in
            XCTAssertEqual(url?.absoluteString, "https://grovs.link/retry")
            linkExp.fulfill()
        }

        // Set up success handlers and retry
        setupAuthenticationHandlers()
        MockURLProtocol.requestHandlers["/api/v1/sdk/create_link"] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: ["link": "https://grovs.link/retry"])
            return (response, data)
        }

        let retryExp = expectation(description: "retry auth succeeds")
        manager.authenticate { success in
            XCTAssertTrue(success, "Retry auth should succeed")
            retryExp.fulfill()
        }

        wait(for: [retryExp, linkExp], timeout: 10)
    }

    // MARK: - Action queue cap

    func testActionQueueEvictsOldestWhenFull() {
        let manager = makeTestableManager()

        var evictedCount = 0
        // Queue 1001 actions (cap is 1000) — the first should be evicted
        for i in 0..<1001 {
            manager.generateLink(title: "Link \(i)", subtitle: nil, imageURL: nil,
                                 data: nil, tags: nil, customRedirects: nil,
                                 showPreviewiOS: nil, showPreviewAndroid: nil) { url in
                if url == nil {
                    evictedCount += 1
                }
            }
        }

        // The 1st action should have been evicted (failureBlock called with nil)
        XCTAssertEqual(evictedCount, 1,
                       "Oldest action should be evicted when queue exceeds cap")
    }

    // MARK: - Auth failure drains action queue

    func testFailedAuthCallsFailureBlockOnQueuedGenerateLink() {
        let manager = makeTestableManager()

        // Queue a generateLink action before auth
        let linkExp = expectation(description: "generateLink failure")
        manager.generateLink(title: "Test", subtitle: nil, imageURL: nil,
                             data: nil, tags: nil, customRedirects: nil,
                             showPreviewiOS: nil, showPreviewAndroid: nil) { url in
            XCTAssertNil(url, "Failed auth should call generateLink completion with nil")
            linkExp.fulfill()
        }

        // Auth fails (500 on authenticate endpoint)
        MockURLProtocol.requestHandlers["/api/v1/sdk/authenticate"] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }

        let authExp = expectation(description: "auth fails")
        manager.authenticate { success in
            XCTAssertFalse(success)
            authExp.fulfill()
        }

        wait(for: [authExp, linkExp], timeout: 5)
    }

    func testFailedAuthClearsActionQueue() {
        let manager = makeTestableManager()

        // Queue two actions
        let exp1 = expectation(description: "action 1 failure")
        manager.generateLink(title: "A", subtitle: nil, imageURL: nil,
                             data: nil, tags: nil, customRedirects: nil,
                             showPreviewiOS: nil, showPreviewAndroid: nil) { url in
            XCTAssertNil(url)
            exp1.fulfill()
        }

        let exp2 = expectation(description: "action 2 failure")
        manager.getNotifications(page: 1) { notifications in
            XCTAssertNil(notifications)
            exp2.fulfill()
        }

        // Fail auth
        MockURLProtocol.requestHandlers["/api/v1/sdk/authenticate"] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }

        let authExp = expectation(description: "auth fails")
        manager.authenticate { success in
            XCTAssertFalse(success)
            authExp.fulfill()
        }

        wait(for: [authExp, exp1, exp2], timeout: 5)

        // Now succeed auth — old actions should NOT re-fire
        setupAuthenticationHandlers()
        MockURLProtocol.requestHandlers["/api/v1/sdk/create_link"] = { request in
            XCTFail("Old generateLink action should not re-fire after failed auth cleared the queue")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: ["link": "https://grovs.link/stale"])
            return (response, data)
        }

        let retryAuthExp = expectation(description: "retry auth succeeds")
        manager.authenticate { success in
            XCTAssertTrue(success)
            retryAuthExp.fulfill()
        }
        wait(for: [retryAuthExp], timeout: 5)
    }

    func testQueuedLogInAppPurchaseFailsOnFailedAuth() {
        let manager = makeTestableManager()

        let purchaseExp = expectation(description: "purchase failure")
        manager.logInAppPurchase(transactionID: 999) { success in
            XCTAssertFalse(success, "Queued logInAppPurchase should return false on auth failure")
            purchaseExp.fulfill()
        }

        MockURLProtocol.requestHandlers["/api/v1/sdk/authenticate"] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }

        let authExp = expectation(description: "auth fails")
        manager.authenticate { success in
            XCTAssertFalse(success)
            authExp.fulfill()
        }

        wait(for: [authExp, purchaseExp], timeout: 5)
    }

    func testQueuedDisplayMessagesFailsOnFailedAuth() {
        let manager = makeTestableManager()

        let displayExp = expectation(description: "displayMessages failure")
        manager.displayMessagesViewController {
            displayExp.fulfill()
        }

        MockURLProtocol.requestHandlers["/api/v1/sdk/authenticate"] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }

        let authExp = expectation(description: "auth fails")
        manager.authenticate { success in
            XCTAssertFalse(success)
            authExp.fulfill()
        }

        wait(for: [authExp, displayExp], timeout: 5)
    }

    // MARK: - Notifications

    func testGetNotificationsWorksAfterAuthentication() {
        let manager = makeTestableManager()
        setupAuthenticationHandlers()
        MockURLProtocol.requestHandlers["/api/v1/sdk/notifications_for_device"] = { request in
            let json: [String: Any] = [
                "notifications": [
                    ["id": 1, "title": "Notif", "updated_at": "2024-06-15T10:30:00.000+0000",
                     "auto_display": false, "read": false]
                ]
            ]
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: json)
            return (response, data)
        }

        authenticateAndWait(manager)

        let notifExp = expectation(description: "notifications")
        manager.getNotifications(page: 1) { notifications in
            XCTAssertEqual(notifications?.count, 1)
            XCTAssertEqual(notifications?.first?.title, "Notif")
            notifExp.fulfill()
        }
        wait(for: [notifExp], timeout: 5)
    }
}
