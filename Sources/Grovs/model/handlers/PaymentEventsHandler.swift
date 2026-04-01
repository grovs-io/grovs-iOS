//
//  PaymentsEventsHandler.swift
//
//  grovs
//

import UIKit

/// Manages event handling and dispatching for the application.
class PaymentEventsHandler {

    private let service: APIServiceProtocol
    private let storage: PaymentEventsStorageProtocol
    private var started = false

    // MARK: Initialization

    /// Initializes the `PaymentEventsHandler` with the provided API service.
    /// - Parameter apiService: The service used for API calls
    /// - Parameter storage: The payment events storage
    init(apiService: APIServiceProtocol,
         storage: PaymentEventsStorageProtocol = PaymentEventsStorage()) {
        self.service = apiService
        self.storage = storage
    }

    // MARK: Public Methods

    func start() {
        guard !started else { return }

        addObservers()
        started = true
    }

    /// Logs an event and sends it to the backend.
    /// - Parameter event: The event to log
    func logInAppPurchase(transactionID: UInt64, completion: @escaping GrovsBoolCompletion) {
        guard started else {
            DebugLogger.shared.log(.error, "You need to be authenticated to start sending payment events.")
            completion(false)

            return
        }

        guard !storage.isTransactionHandled(transactionID: transactionID) else {
            completion(true)
            return
        }

        let data = TransactionData(type: .buy, price: nil, transactionID: transactionID, oldTransactionID: nil, currency: nil, productID: nil, bundleID: AppDetailsHelper.getBundleID(), startDate: nil, store: true)

        sendTransactionToBackend(transaction: data, completion: completion)
    }

    /// Logs a custom purchase transaction and sends it to the backend.
    ///
    /// - Parameters:
    ///   - type: The type of transaction (e.g., purchase, refund).
    ///   - priceInCents: The price of the transaction in cents.
    ///   - currency: The currency of the transaction (e.g., "USD").
    ///   - productID: A product identifier typically, the name of the service.
    ///   - startDate: An optional start date for the transaction. Defaults to the current date if not provided.
    ///   - completion: A closure that gets called once the transaction is processed.
    func logCustomPurchase(type: TransactionType, priceInCents: Int, currency: String, productID: String, startDate: Date? = nil, completion: @escaping GrovsBoolCompletion) {
        guard started else {
            DebugLogger.shared.log(.error, "You need to be authenticated to start sending payment events.")
            completion(false)

            return
        }

        var date = startDate
        if startDate == nil {
            date = Date()
        }

        let data = TransactionData(type: type, price: priceInCents, transactionID: nil, oldTransactionID: nil, currency: currency, productID: productID, bundleID: AppDetailsHelper.getBundleID(), startDate: date, store: false)

        sendTransactionToBackend(transaction: data, completion: completion)
    }

    // MARK: Notifications

    /// Called when the application becomes active.
    @objc func applicationDidBecomeActive() {
        retryPendingTransactions()
    }

    // MARK: Private Methods

    /// Sets up observers for application lifecycle notifications.
    private func addObservers() {
        // Add observers for application lifecycle notifications
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    private static let maxPendingRetries = 5

    private func retryPendingTransactions() {
        let pending = storage.fetchPendingTransactions()
        for entry in pending {
            if entry.retryCount >= Self.maxPendingRetries {
                DebugLogger.shared.log(.error, "Discarding pending transaction after \(entry.retryCount) failed retries: \(entry.transaction.productID ?? "unknown")")
                storage.removePendingTransaction(id: entry.id)
                continue
            }

            storage.incrementRetryCount(id: entry.id)
            service.addPaymentEvent(transactionData: entry.transaction) { result in
                if result {
                    self.storage.removePendingTransaction(id: entry.id)
                }
            }
        }
    }

    private func sendTransactionToBackend(transaction: TransactionData, completion: GrovsBoolCompletion? = nil) {
        service.addPaymentEvent(transactionData: transaction, completion: { result in
            if result {
                self.markTransactionAsHandledIfNeeded(transaction: transaction)
            } else if !transaction.store {
                // Custom purchases have no StoreKit-based retry — persist for retry on next foreground
                self.storage.savePendingTransaction(transaction)
            }

            completion?(result)
        })
    }

    private func markTransactionAsHandledIfNeeded(transaction: TransactionData) {
        guard let transactionID = transaction.transactionID else {
            return
        }

        storage.markTransactionAsHandled(transactionID: transactionID)
    }

}
