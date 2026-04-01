import XCTest
@testable import Grovs

final class APIServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        BaseService.urlProtocolClasses = [MockURLProtocol.self]
    }

    override func tearDown() {
        BaseService.urlProtocolClasses = []
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeService(useTestEnvironment: Bool = false) -> APIService {
        return APIService(apiKey: "test-api-key", bundleID: "com.test.bundle", useTestEnvironment: useTestEnvironment)
    }

    // MARK: - addEvent

    func testAddEventSendsCorrectRequestOnSuccess() {
        let service = makeService()
        let event = Event(type: .appOpen, createdAt: Date(), link: "https://test.com")

        MockURLProtocol.requestHandlers["/api/v1/sdk/event"] = { request in
            // Verify headers
            XCTAssertEqual(request.value(forHTTPHeaderField: "PROJECT-KEY"), "test-api-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "IDENTIFIER"), "com.test.bundle")
            XCTAssertEqual(request.value(forHTTPHeaderField: "PLATFORM"), "ios")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.httpMethod, "POST")

            // Verify body contains event data
            if let body = request.httpBody, let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                XCTAssertEqual(json["event"] as? String, "app_open")
                XCTAssertEqual(json["link"] as? String, "https://test.com")
            } else {
                XCTFail("Request body should contain valid JSON")
            }

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: ["status": "ok"])
            return (response, data)
        }

        let exp = expectation(description: "addEvent")
        service.addEvent(event: event) { success in
            XCTAssertTrue(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testAddEventReturnsFalseOnServerError() {
        let service = makeService()
        let event = Event(type: .install, createdAt: Date())

        MockURLProtocol.requestHandlers["/api/v1/sdk/event"] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: ["error": "server error"])
            return (response, data)
        }

        let exp = expectation(description: "addEvent failure")
        service.addEvent(event: event) { success in
            XCTAssertFalse(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - addPaymentEvent

    func testAddPaymentEventSendsCorrectBody() {
        let service = makeService()
        let transaction = TransactionData(
            type: .buy, price: 999, transactionID: 12345,
            oldTransactionID: nil, currency: "USD",
            productID: "com.test.product", bundleID: "com.test.bundle",
            startDate: Date(), store: true
        )

        MockURLProtocol.requestHandlers["/api/v1/sdk/add_payment_event"] = { request in
            XCTAssertEqual(request.httpMethod, "POST")

            if let body = request.httpBody, let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                XCTAssertEqual(json["event_type"] as? String, "buy")
                XCTAssertEqual(json["price_cents"] as? Int, 999)
                XCTAssertEqual(json["currency"] as? String, "USD")
                XCTAssertEqual(json["product_id"] as? String, "com.test.product")
            } else {
                XCTFail("Request body should contain valid JSON")
            }

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: ["status": "ok"])
            return (response, data)
        }

        let exp = expectation(description: "addPaymentEvent")
        service.addPaymentEvent(transactionData: transaction) { success in
            XCTAssertTrue(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testAddPaymentEventReturnsFalseOnFailure() {
        let service = makeService()
        let transaction = TransactionData(
            type: .refund, price: 500, transactionID: 99,
            oldTransactionID: nil, currency: "EUR",
            productID: "prod", bundleID: "com.test",
            startDate: Date(), store: false
        )

        MockURLProtocol.requestHandlers["/api/v1/sdk/add_payment_event"] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 422, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: ["error": "invalid"])
            return (response, data)
        }

        let exp = expectation(description: "addPaymentEvent failure")
        service.addPaymentEvent(transactionData: transaction) { success in
            XCTAssertFalse(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - Test environment key prefix

    func testTestEnvironmentAddsKeyPrefix() {
        let service = makeService(useTestEnvironment: true)
        let event = Event(type: .view, createdAt: Date())

        MockURLProtocol.requestHandlers["/api/v1/sdk/event"] = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "PROJECT-KEY"), "test_test-api-key",
                           "Test environment should prefix the API key with 'test_'")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: ["status": "ok"])
            return (response, data)
        }

        let exp = expectation(description: "test env")
        service.addEvent(event: event) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testProductionEnvironmentUsesRawKey() {
        let service = makeService(useTestEnvironment: false)
        let event = Event(type: .view, createdAt: Date())

        MockURLProtocol.requestHandlers["/api/v1/sdk/event"] = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "PROJECT-KEY"), "test-api-key",
                           "Production environment should use the raw API key")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: ["status": "ok"])
            return (response, data)
        }

        let exp = expectation(description: "prod env")
        service.addEvent(event: event) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - SDK Version header

    func testSDKVersionHeaderIsSet() {
        let service = makeService()
        let event = Event(type: .appOpen, createdAt: Date())

        MockURLProtocol.requestHandlers["/api/v1/sdk/event"] = { request in
            XCTAssertNotNil(request.value(forHTTPHeaderField: "SDK-VERSION"),
                            "SDK-VERSION header should be present")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: ["status": "ok"])
            return (response, data)
        }

        let exp = expectation(description: "sdk version")
        service.addEvent(event: event) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - Helpers

    private var testAppDetails: AppDetails {
        AppDetails(version: "1.0", build: "1", bundle: "com.test",
                   device: "iPhone", deviceID: "test-device",
                   userAgent: "TestAgent", screenWidth: 375,
                   screenHeight: 812, language: "en", timeZone: "UTC")
    }

    private func okResponse(for request: URLRequest, json: [String: Any] = ["status": "ok"]) throws -> (HTTPURLResponse, Data?) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let data = try JSONSerialization.data(withJSONObject: json)
        return (response, data)
    }

    private func errorResponse(for request: URLRequest, statusCode: Int = 500) throws -> (HTTPURLResponse, Data?) {
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        let data = try JSONSerialization.data(withJSONObject: ["error": "fail"])
        return (response, data)
    }

    // MARK: - authenticate

    func testAuthenticateReturnsCredentialsOnSuccess() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/authenticate"] = { request in
            XCTAssertEqual(request.httpMethod, "POST")

            // Verify request body contains app details
            if let body = request.httpBody,
               let bodyJSON = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                XCTAssertEqual(bodyJSON["vendor_id"] as? String, "test-device")
                XCTAssertEqual(bodyJSON["app_version"] as? String, "1.0")
                XCTAssertEqual(bodyJSON["build"] as? String, "1")
                XCTAssertEqual(bodyJSON["device"] as? String, "iPhone")
                XCTAssertEqual(bodyJSON["user_agent"] as? String, "TestAgent")
            } else {
                XCTFail("Request body should contain app details")
            }

            let json: [String: Any] = [
                "linksquared": "ls-id-123",
                "uri_scheme": "myapp://",
                "sdk_identifier": "user-42",
                "sdk_attributes": ["plan": "pro"]
            ]
            return try self.okResponse(for: request, json: json)
        }

        let exp = expectation(description: "authenticate")
        service.authenticate(appDetails: testAppDetails) { success, linksquaredID, uriScheme, identifier, attributes in
            XCTAssertTrue(success)
            XCTAssertEqual(linksquaredID, "ls-id-123")
            XCTAssertEqual(uriScheme, "myapp://")
            XCTAssertEqual(identifier, "user-42")
            XCTAssertEqual(attributes?["plan"] as? String, "pro")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testAuthenticateReturnsFalseOnMissingFields() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/authenticate"] = { request in
            // Missing linksquared and uri_scheme
            return try self.okResponse(for: request, json: ["other": "data"])
        }

        let exp = expectation(description: "authenticate fail")
        service.authenticate(appDetails: testAppDetails) { success, linksquaredID, uriScheme, identifier, attributes in
            XCTAssertFalse(success)
            XCTAssertNil(linksquaredID)
            XCTAssertNil(uriScheme)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - payloadFor(appDetails:)

    func testPayloadForDeviceReturnsDataLinkTracking() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/data_for_device"] = { request in
            XCTAssertEqual(request.httpMethod, "POST")

            let json: [String: Any] = [
                "data": ["key": "value"],
                "link": "https://example.com/deep",
                "tracking": ["campaign": "summer"]
            ]
            return try self.okResponse(for: request, json: json)
        }

        let exp = expectation(description: "payloadForDevice")
        service.payloadFor(appDetails: testAppDetails) { data, link, tracking in
            XCTAssertEqual(data?["key"] as? String, "value")
            XCTAssertEqual(link, "https://example.com/deep")
            XCTAssertEqual(tracking?["campaign"] as? String, "summer")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testPayloadForDeviceReturnsNilOnFailure() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/data_for_device"] = { request in
            return try self.errorResponse(for: request)
        }

        let exp = expectation(description: "payloadForDevice fail")
        service.payloadFor(appDetails: testAppDetails) { data, link, tracking in
            XCTAssertNil(data)
            XCTAssertNil(link)
            XCTAssertNil(tracking)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - payloadFor(appDetails:url:)

    func testPayloadForDeviceAndURLIncludesURLInBody() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/data_for_device_and_url"] = { request in
            XCTAssertEqual(request.httpMethod, "POST")

            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                XCTAssertEqual(json["url"] as? String, "https://test.com/path")
            } else {
                XCTFail("Request body should contain url")
            }

            let json: [String: Any] = [
                "data": ["screen": "home"],
                "link": "https://test.com/path",
                "tracking": ["source": "email"]
            ]
            return try self.okResponse(for: request, json: json)
        }

        let exp = expectation(description: "payloadForDeviceAndURL")
        service.payloadFor(appDetails: testAppDetails, url: "https://test.com/path") { data, link, tracking in
            XCTAssertEqual(data?["screen"] as? String, "home")
            XCTAssertEqual(link, "https://test.com/path")
            XCTAssertEqual(tracking?["source"] as? String, "email")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - generateLink

    func testGenerateLinkReturnsURLOnSuccess() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/create_link"] = { request in
            XCTAssertEqual(request.httpMethod, "POST")

            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                XCTAssertEqual(json["title"] as? String, "My Link")
                XCTAssertEqual(json["subtitle"] as? String, "Sub")
            }

            return try self.okResponse(for: request, json: ["link": "https://grovs.link/abc123"])
        }

        let exp = expectation(description: "generateLink")
        service.generateLink(title: "My Link", subtitle: "Sub", imageURL: nil,
                             data: nil, tags: nil, customRedirects: nil,
                             showPreviewiOS: nil, showPreviewAndroid: nil) { url in
            XCTAssertEqual(url?.absoluteString, "https://grovs.link/abc123")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testGenerateLinkReturnsNilOnFailure() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/create_link"] = { request in
            return try self.errorResponse(for: request)
        }

        let exp = expectation(description: "generateLink fail")
        service.generateLink(title: nil, subtitle: nil, imageURL: nil,
                             data: nil, tags: nil, customRedirects: nil,
                             showPreviewiOS: nil, showPreviewAndroid: nil) { url in
            XCTAssertNil(url)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - notifications

    func testNotificationsDecodesResponseOnSuccess() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/notifications_for_device"] = { request in
            XCTAssertEqual(request.httpMethod, "POST")

            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                XCTAssertEqual(json["page"] as? Int, 1)
            }

            let json: [String: Any] = [
                "notifications": [
                    [
                        "id": 10,
                        "title": "Hello",
                        "updated_at": "2024-06-15T10:30:00.000+0000",
                        "auto_display": false,
                        "read": false
                    ]
                ]
            ]
            return try self.okResponse(for: request, json: json)
        }

        let exp = expectation(description: "notifications")
        service.notifications(page: 1) { notifications in
            XCTAssertEqual(notifications?.count, 1)
            XCTAssertEqual(notifications?.first?.id, 10)
            XCTAssertEqual(notifications?.first?.title, "Hello")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testNotificationsReturnsNilOnFailure() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/notifications_for_device"] = { request in
            return try self.errorResponse(for: request)
        }

        let exp = expectation(description: "notifications fail")
        service.notifications(page: 1) { notifications in
            XCTAssertNil(notifications)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - numberOfUnreadNotifications

    func testNumberOfUnreadNotificationsReturnsCount() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/number_of_unread_notifications"] = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            return try self.okResponse(for: request, json: ["number_of_unread_notifications": 5])
        }

        let exp = expectation(description: "unread count")
        service.numberOfUnreadNotifications { count in
            XCTAssertEqual(count, 5)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testNumberOfUnreadNotificationsReturnsNilOnFailure() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/number_of_unread_notifications"] = { request in
            return try self.errorResponse(for: request)
        }

        let exp = expectation(description: "unread count fail")
        service.numberOfUnreadNotifications { count in
            XCTAssertNil(count)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - markNotificationAsRead

    func testMarkNotificationAsReadSendsIDAndReturnsTrue() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/mark_notification_as_read"] = { request in
            XCTAssertEqual(request.httpMethod, "POST")

            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                XCTAssertEqual(json["id"] as? Int, 42)
            } else {
                XCTFail("Request body should contain notification id")
            }

            return try self.okResponse(for: request)
        }

        let exp = expectation(description: "mark read")
        service.markNotificationAsRead(notificationID: 42) { success in
            XCTAssertTrue(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testMarkNotificationAsReadReturnsFalseOnFailure() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/mark_notification_as_read"] = { request in
            return try self.errorResponse(for: request)
        }

        let exp = expectation(description: "mark read fail")
        service.markNotificationAsRead(notificationID: 99) { success in
            XCTAssertFalse(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - notificationsToDisplayAutomatically

    func testNotificationsToDisplayAutomaticallyDecodesResponse() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/notifications_to_display_automatically"] = { request in
            XCTAssertEqual(request.httpMethod, "GET")

            let json: [String: Any] = [
                "notifications": [
                    [
                        "id": 7,
                        "title": "Auto",
                        "updated_at": "2024-01-01T00:00:00.000+0000",
                        "auto_display": true,
                        "read": false
                    ]
                ]
            ]
            return try self.okResponse(for: request, json: json)
        }

        let exp = expectation(description: "auto notifications")
        service.notificationsToDisplayAutomatically { notifications in
            XCTAssertEqual(notifications?.count, 1)
            XCTAssertEqual(notifications?.first?.title, "Auto")
            XCTAssertTrue(notifications?.first?.autoDisplay == true)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - updateAttributes

    func testUpdateAttributesReturnsTrueOnSuccess() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/visitor_attributes"] = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            return try self.okResponse(for: request)
        }

        let exp = expectation(description: "update attrs")
        service.updateAttributes { success in
            XCTAssertTrue(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testUpdateAttributesReturnsFalseOnFailure() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/visitor_attributes"] = { request in
            return try self.errorResponse(for: request)
        }

        let exp = expectation(description: "update attrs fail")
        service.updateAttributes { success in
            XCTAssertFalse(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - linkDetails

    func testLinkDetailsReturnsDataOnSuccess() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/link_details"] = { request in
            XCTAssertEqual(request.httpMethod, "POST")

            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                XCTAssertEqual(json["path"] as? String, "/abc123")
            }

            let json: [String: Any] = [
                "title": "My Link",
                "clicks": 42,
                "created_at": "2024-06-15"
            ]
            return try self.okResponse(for: request, json: json)
        }

        let exp = expectation(description: "link details")
        service.linkDetails(path: "/abc123") { details in
            XCTAssertEqual(details?["title"] as? String, "My Link")
            XCTAssertEqual(details?["clicks"] as? Int, 42)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testLinkDetailsReturnsNilOnFailure() {
        let service = makeService()

        MockURLProtocol.requestHandlers["/api/v1/sdk/link_details"] = { request in
            return try self.errorResponse(for: request)
        }

        let exp = expectation(description: "link details fail")
        service.linkDetails(path: "/xyz") { details in
            XCTAssertNil(details)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }
}
