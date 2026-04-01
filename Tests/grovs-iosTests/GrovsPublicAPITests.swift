import XCTest
@testable import Grovs

final class GrovsPublicAPITests: XCTestCase {

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

    // MARK: - Unconfigured SDK (no configure() called)

    func testDelegateIsNilBeforeConfigure() {
        XCTAssertNil(Grovs.delegate)
    }

    func testSetUserIdentifierDoesNotCrashBeforeConfigure() {
        Grovs.userIdentifier = "test-id"
        // No crash = pass; value is discarded since there's no manager
        XCTAssertNil(Grovs.userIdentifier)
    }

    func testGenerateLinkReturnsNilBeforeConfigure() {
        // Reset manager by configuring with empty key (sets manager to nil)
        let setupExp = expectation(description: "setup")
        Grovs.configure(APIKey: "", useTestEnvironment: true, delegate: nil) { _ in
            setupExp.fulfill()
        }
        wait(for: [setupExp], timeout: 5)

        let exp = expectation(description: "completion called")
        Grovs.generateLink(title: "Test") { url in
            XCTAssertNil(url, "Should return nil when SDK is not configured")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - configure

    func testConfigureWithEmptyKeyCallsCompletionFalse() {
        let exp = expectation(description: "completion")
        Grovs.configure(APIKey: "", useTestEnvironment: true, delegate: nil) { success in
            XCTAssertFalse(success, "Empty API key should fail configuration")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testConfigureWithValidKeyTriggersAuthentication() {
        // In the test runner, hasURISchemesConfigured() returns false so authenticate fails.
        // This validates the full configure → checkConfiguration → authenticate chain.
        let exp = expectation(description: "completion")
        Grovs.configure(APIKey: "test-key", useTestEnvironment: true, delegate: nil) { success in
            XCTAssertFalse(success, "Auth should fail without URI schemes in test bundle")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - Pre-configure guard behavior

    func testAllReceivedPayloadsBeforeConfigureReturnsNil() {
        // Reset manager by configuring with empty key
        let setupExp = expectation(description: "setup")
        Grovs.configure(APIKey: "", useTestEnvironment: true, delegate: nil) { _ in
            setupExp.fulfill()
        }
        wait(for: [setupExp], timeout: 5)

        let exp = expectation(description: "payloads")
        Grovs.allReceivedPayloadsSinceStartup { payloads in
            XCTAssertNil(payloads)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testLogInAppPurchaseBeforeConfigureReturnsFalse() {
        let setupExp = expectation(description: "setup")
        Grovs.configure(APIKey: "", useTestEnvironment: true, delegate: nil) { _ in
            setupExp.fulfill()
        }
        wait(for: [setupExp], timeout: 5)

        let exp = expectation(description: "purchase")
        Grovs.logInAppPurchase(transactionID: 123) { success in
            XCTAssertFalse(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testLogCustomPurchaseBeforeConfigureReturnsFalse() {
        let setupExp = expectation(description: "setup")
        Grovs.configure(APIKey: "", useTestEnvironment: true, delegate: nil) { _ in
            setupExp.fulfill()
        }
        wait(for: [setupExp], timeout: 5)

        let exp = expectation(description: "custom purchase")
        Grovs.logCustomPurchase(type: .buy, priceInCents: 100, currency: "USD", productID: "test") { success in
            XCTAssertFalse(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - Debug level

    func testSetDebugLevelChangesLogLevel() {
        let original = DebugLogger.shared.logLevel
        defer { DebugLogger.shared.logLevel = original }

        Grovs.setDebug(level: .info)
        XCTAssertEqual(DebugLogger.shared.logLevel, .info)

        Grovs.setDebug(level: .error)
        XCTAssertEqual(DebugLogger.shared.logLevel, .error)
    }
}
