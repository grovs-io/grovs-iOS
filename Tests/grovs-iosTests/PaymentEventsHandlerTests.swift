import XCTest
@testable import Grovs

final class PaymentEventsHandlerTests: XCTestCase {

    private var mockService: MockAPIService!
    private var mockStorage: MockPaymentEventsStorage!

    override func setUp() {
        super.setUp()
        mockService = MockAPIService()
        mockStorage = MockPaymentEventsStorage()
    }

    override func tearDown() {
        mockService = nil
        mockStorage = nil
        super.tearDown()
    }

    private func makeHandler() -> PaymentEventsHandler {
        return PaymentEventsHandler(
            apiService: mockService,
            storage: mockStorage
        )
    }

    // MARK: - start()

    func testMultipleStartCallsDoNotDuplicateObservers() {
        let handler = makeHandler()
        handler.start()
        handler.start()
        handler.start()

        mockService.reset()

        // Simulate didBecomeActive with a pending transaction — should trigger exactly one retry,
        // not three (which would happen with duplicate observers).
        let pending = TransactionData(
            type: .buy, price: 100, transactionID: nil,
            oldTransactionID: nil, currency: "USD",
            productID: "prod", bundleID: "com.test",
            startDate: Date(), store: false
        )
        mockStorage.savePendingTransaction(pending)
        mockStorage.savePendingCallCount = 0

        handler.applicationDidBecomeActive()

        XCTAssertEqual(mockService.addPaymentEventCallCount, 1,
                       "Multiple start() calls should not register duplicate observers")
    }

    // MARK: - logInAppPurchase

    func testLogInAppPurchaseReturnsFalseBeforeStart() {
        let handler = makeHandler()

        let exp = expectation(description: "completion")
        handler.logInAppPurchase(transactionID: 123) { success in
            XCTAssertFalse(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addPaymentEventCallCount, 0,
                       "Should not call API before start()")
    }

    func testLogInAppPurchaseCreatesCorrectTransactionData() {
        let handler = makeHandler()
        handler.start()
        mockService.reset()

        let exp = expectation(description: "purchase logged")
        handler.logInAppPurchase(transactionID: 555) { success in
            XCTAssertTrue(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addPaymentEventCallCount, 1)

        let sent = mockService.allTransactionData.first
        XCTAssertEqual(sent?.transactionID, 555)
        XCTAssertEqual(sent?.type, .buy)
        XCTAssertEqual(sent?.store, true)
        XCTAssertEqual(sent?.bundleID, AppDetailsHelper.getBundleID(),
                       "bundleID should match the app's bundle ID")
        XCTAssertNil(sent?.price, "logInAppPurchase does not set price")
        XCTAssertNil(sent?.currency, "logInAppPurchase does not set currency")
        XCTAssertNil(sent?.oldTransactionID)
        XCTAssertNil(sent?.productID)
        XCTAssertNil(sent?.startDate)
    }

    // MARK: - logCustomPurchase

    func testLogCustomPurchaseReturnsFalseBeforeStart() {
        let handler = makeHandler()

        let exp = expectation(description: "completion")
        handler.logCustomPurchase(
            type: .buy, priceInCents: 500,
            currency: "USD", productID: "prod"
        ) { success in
            XCTAssertFalse(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addPaymentEventCallCount, 0)
    }

    func testLogCustomPurchaseCreatesCorrectTransactionData() {
        let handler = makeHandler()
        handler.start()
        mockService.reset()

        let exp = expectation(description: "custom purchase logged")
        handler.logCustomPurchase(
            type: .refund,
            priceInCents: 1999,
            currency: "EUR",
            productID: "com.app.premium"
        ) { success in
            XCTAssertTrue(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addPaymentEventCallCount, 1)

        let sent = mockService.allTransactionData.first
        XCTAssertEqual(sent?.type, .refund)
        XCTAssertEqual(sent?.price, 1999)
        XCTAssertEqual(sent?.currency, "EUR")
        XCTAssertEqual(sent?.productID, "com.app.premium")
        XCTAssertEqual(sent?.store, false,
                       "Custom purchases should have store = false")
        XCTAssertNotNil(sent?.startDate,
                        "startDate should default to current date when nil")
    }

    func testLogCustomPurchaseWithExplicitStartDate() {
        let handler = makeHandler()
        handler.start()
        mockService.reset()

        let specificDate = Date(timeIntervalSince1970: 1_000_000)

        let exp = expectation(description: "custom purchase with date")
        handler.logCustomPurchase(
            type: .buy,
            priceInCents: 500,
            currency: "USD",
            productID: "prod",
            startDate: specificDate
        ) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        let sent = mockService.allTransactionData.first
        XCTAssertEqual(sent?.startDate, specificDate,
                       "Should use the explicit startDate, not default to Date()")
    }

    // MARK: - sendTransactionToBackend

    func testSendTransactionMarksAsHandledOnSuccess() {
        mockService.addPaymentEventResult = true

        let handler = makeHandler()
        handler.start()

        let transactionID: UInt64 = 999
        let exp = expectation(description: "transaction sent")
        handler.logInAppPurchase(transactionID: transactionID) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertTrue(mockStorage.isTransactionHandled(transactionID: transactionID))
        XCTAssertEqual(mockStorage.markCallCount, 1,
                       "markTransactionAsHandled should be called exactly once")
    }

    func testSendTransactionDoesNotMarkAsHandledOnFailure() {
        mockService.addPaymentEventResult = false

        let handler = makeHandler()
        handler.start()

        let transactionID: UInt64 = 888
        let exp = expectation(description: "transaction failed")
        handler.logInAppPurchase(transactionID: transactionID) { success in
            XCTAssertFalse(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertFalse(mockStorage.isTransactionHandled(transactionID: transactionID))
        XCTAssertEqual(mockStorage.markCallCount, 0,
                       "markTransactionAsHandled should NOT be called on failure")
    }

    func testSendTransactionWithNilTransactionIDDoesNotMarkAsHandled() {
        mockService.addPaymentEventResult = true

        // Create a transaction with nil transactionID (custom purchase path)
        let handler = makeHandler()
        handler.start()
        mockService.reset()
        mockStorage.reset()

        let exp = expectation(description: "custom purchase")
        handler.logCustomPurchase(
            type: .buy, priceInCents: 100,
            currency: "USD", productID: "prod"
        ) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addPaymentEventCallCount, 1,
                       "API should still be called")
        XCTAssertNil(mockService.allTransactionData.first?.transactionID)
        XCTAssertEqual(mockStorage.markCallCount, 0,
                       "Should not mark as handled when transactionID is nil")
    }

    // MARK: - logInAppPurchase deduplication

    func testLogInAppPurchaseSkipsAlreadyHandledTransaction() {
        let handler = makeHandler()
        handler.start()
        mockService.reset()

        let transactionID: UInt64 = 444
        mockStorage.markTransactionAsHandled(transactionID: transactionID)

        let exp = expectation(description: "already handled")
        handler.logInAppPurchase(transactionID: transactionID) { success in
            XCTAssertTrue(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addPaymentEventCallCount, 0,
                       "Already-handled transaction should not be sent via logInAppPurchase")
    }

    func testLogInAppPurchaseSendsUnhandledTransaction() {
        let handler = makeHandler()
        handler.start()
        mockService.reset()

        let exp = expectation(description: "unhandled sent")
        handler.logInAppPurchase(transactionID: 555) { success in
            XCTAssertTrue(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addPaymentEventCallCount, 1,
                       "Unhandled transaction should be sent")
    }

    // MARK: - Custom purchase retry on failure

    func testFailedCustomPurchaseIsSavedForRetry() {
        let handler = makeHandler()
        handler.start()
        mockService.reset()
        mockStorage.reset()
        mockService.addPaymentEventResult = false

        let exp = expectation(description: "custom purchase failed")
        handler.logCustomPurchase(
            type: .buy, priceInCents: 999,
            currency: "USD", productID: "prod"
        ) { success in
            XCTAssertFalse(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockStorage.savePendingCallCount, 1,
                       "Failed custom purchase should be saved for retry")
        XCTAssertEqual(mockStorage.pendingTransactions.count, 1)
        XCTAssertEqual(mockStorage.pendingTransactions.first?.transaction.productID, "prod")
    }

    func testFailedIAPIsNotSavedForRetry() {
        let handler = makeHandler()
        handler.start()
        mockService.reset()
        mockStorage.reset()
        mockService.addPaymentEventResult = false

        let exp = expectation(description: "IAP failed")
        handler.logInAppPurchase(transactionID: 123) { success in
            XCTAssertFalse(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockStorage.savePendingCallCount, 0,
                       "IAP failures should NOT be saved — StoreKit retries them automatically")
    }

    func testSuccessfulCustomPurchaseIsNotSavedForRetry() {
        mockService.addPaymentEventResult = true

        let handler = makeHandler()
        handler.start()
        mockService.reset()
        mockStorage.reset()

        let exp = expectation(description: "custom purchase succeeded")
        handler.logCustomPurchase(
            type: .buy, priceInCents: 500,
            currency: "EUR", productID: "premium"
        ) { success in
            XCTAssertTrue(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockStorage.savePendingCallCount, 0,
                       "Successful custom purchase should NOT be saved for retry")
    }

    func testDidBecomeActiveRetriesPendingTransactions() {
        let handler = makeHandler()
        handler.start()
        mockService.reset()

        // Simulate a previously failed custom purchase in storage
        let pending = TransactionData(
            type: .refund, price: 1500, transactionID: nil,
            oldTransactionID: nil, currency: "GBP",
            productID: "sub.annual", bundleID: "com.test",
            startDate: Date(), store: false
        )
        mockStorage.savePendingTransaction(pending)
        mockStorage.savePendingCallCount = 0

        handler.applicationDidBecomeActive()

        XCTAssertEqual(mockService.addPaymentEventCallCount, 1,
                       "Pending transaction should be retried on didBecomeActive")
        XCTAssertEqual(mockService.allTransactionData.first?.productID, "sub.annual")
        XCTAssertEqual(mockStorage.removePendingCallCount, 1,
                       "Successfully retried transaction should be removed from pending")
        XCTAssertTrue(mockStorage.pendingTransactions.isEmpty)
    }

    func testRetryPendingRemovesSuccessfulOnly() {
        let handler = makeHandler()
        handler.start()
        mockService.reset()

        let pending1 = TransactionData(
            type: .buy, price: 500, transactionID: nil,
            oldTransactionID: nil, currency: "USD",
            productID: "prod.success", bundleID: "com.test",
            startDate: Date(), store: false
        )
        let pending2 = TransactionData(
            type: .refund, price: 200, transactionID: nil,
            oldTransactionID: nil, currency: "EUR",
            productID: "prod.fail", bundleID: "com.test",
            startDate: Date(), store: false
        )
        mockStorage.savePendingTransaction(pending1)
        mockStorage.savePendingTransaction(pending2)
        mockStorage.savePendingCallCount = 0

        // First pending succeeds, second fails
        mockService.addPaymentEventHandler = { transaction in
            return transaction.productID == "prod.success"
        }

        handler.applicationDidBecomeActive()

        XCTAssertEqual(mockService.addPaymentEventCallCount, 2,
                       "Both pending transactions should be retried")
        XCTAssertEqual(mockStorage.removePendingCallCount, 1,
                       "Only the successful transaction should be removed")
        XCTAssertEqual(mockStorage.pendingTransactions.count, 1)
        XCTAssertEqual(mockStorage.pendingTransactions.first?.transaction.productID, "prod.fail",
                       "The failing transaction should remain in pending")
    }

    func testRetryPendingWithEmptyStorageDoesNotCallAPI() {
        let handler = makeHandler()
        handler.start()
        mockService.reset()

        // No pending transactions in storage
        XCTAssertTrue(mockStorage.pendingTransactions.isEmpty)

        handler.applicationDidBecomeActive()

        XCTAssertEqual(mockService.addPaymentEventCallCount, 0,
                       "No pending transactions means no extra API calls for retry")
    }

    func testDidBecomeActiveDoesNotRemoveStillFailingPending() {
        let handler = makeHandler()
        handler.start()
        mockService.reset()
        mockService.addPaymentEventResult = false

        let pending = TransactionData(
            type: .buy, price: 100, transactionID: nil,
            oldTransactionID: nil, currency: "USD",
            productID: "prod", bundleID: "com.test",
            startDate: Date(), store: false
        )
        mockStorage.savePendingTransaction(pending)

        handler.applicationDidBecomeActive()

        XCTAssertEqual(mockStorage.removePendingCallCount, 0,
                       "Still-failing transaction should remain in pending queue")
        XCTAssertEqual(mockStorage.pendingTransactions.count, 1)
    }

    // MARK: - Async dispatch mode

    func testLogInAppPurchaseWorksWithAsyncMockDispatch() {
        mockService.completionQueue = .global()

        let handler = makeHandler()
        handler.start()
        mockService.reset()

        let exp = expectation(description: "async purchase")
        handler.logInAppPurchase(transactionID: 333) { success in
            XCTAssertTrue(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(mockService.addPaymentEventCallCount, 1)
        XCTAssertEqual(mockService.allTransactionData.first?.transactionID, 333)
    }
}
