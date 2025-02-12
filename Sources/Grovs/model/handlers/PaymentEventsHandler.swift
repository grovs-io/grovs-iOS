//
//  PaymentsEventsHandler.swift
//
//  grovs
//

import UIKit

/// Manages event handling and dispatching for the application.
class PaymentEventsHandler {

    private let service: APIService
    private let storage = PaymentEventsStorage()
    private let purchasesHelper = PurchasesHelper()

    // MARK: Initialization

    /// Initializes the `EventsHandler` with the provided API service.
    /// - Parameter apiService: The service used for API calls
    init(apiService: APIService) {
        service = apiService
    }

    // MARK: Public Methods

    func start() {
        addObservers()
        sendCurrentTransactions()
    }

    /// Logs an event and sends it to the backend.
    /// - Parameter event: The event to log
    func logInAppPurchase(transactionID: UInt64, completion: @escaping GrovsBoolCompletion) {
        let data = TransactionData(type: .buy, price: nil, transactionID: transactionID, oldTransactionID: nil, currency: nil, productID: nil, bundleID: AppDetailsHelper.getBundleID(), startDate: nil, store: true)

        sendTransactionToBackend(transaction: data, completion: completion)
    }

    /// Logs a custom purchase transaction and sends it to the backend.
    ///
    /// - Parameters:
    ///   - type: The type of transaction (e.g., purchase, refund).
    ///   - priceInCents: The price of the transaction in cents.
    ///   - currency: The currency of the transaction (e.g., "USD").
    ///   - productID: An optional product identifier.
    ///   - startDate: An optional start date for the transaction. Defaults to the current date if not provided.
    ///   - completion: A closure that gets called once the transaction is processed.
    func logCustomPurchase(type: TransactionType, priceInCents: Int, currency: String, productID: String? = nil, startDate: Date? = nil, completion: @escaping GrovsBoolCompletion) {
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
        sendCurrentTransactions()
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

    private func sendCurrentTransactions() {
        if #available(iOS 15.0, *) {
            purchasesHelper.fetchTransactions { transactions in
                if let transactions {
                    self.handleTransactions(transactions: transactions)
                }
            }
        }
    }

    private func handleTransactions(transactions: [TransactionData]) {
        for transaction in transactions {
            if !storage.isTransactionHandled(transactionID: transaction.transactionID) {
                sendTransactionToBackend(transaction: transaction)
            }
        }
    }

    private func sendTransactionToBackend(transaction: TransactionData, completion: GrovsBoolCompletion? = nil) {
        service.addPaymentEvent(transactionData: transaction, completion: { result in
            if result {
                self.markTransactionAsHandledIfNeeded(transaction: transaction)
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
