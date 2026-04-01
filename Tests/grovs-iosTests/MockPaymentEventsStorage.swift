import Foundation
@testable import Grovs

class MockPaymentEventsStorage: PaymentEventsStorageProtocol {
    var handledTransactions: Set<UInt64> = []
    var pendingTransactions: [PendingTransaction] = []

    var markCallCount = 0
    var removeCallCount = 0
    var isHandledCallCount = 0
    var savePendingCallCount = 0
    var removePendingCallCount = 0

    func markTransactionAsHandled(transactionID: UInt64) {
        markCallCount += 1
        handledTransactions.insert(transactionID)
    }

    func removeEvent(transactionID: UInt64) {
        removeCallCount += 1
        handledTransactions.remove(transactionID)
    }

    func isTransactionHandled(transactionID: UInt64?) -> Bool {
        isHandledCallCount += 1
        guard let transactionID else { return false }
        return handledTransactions.contains(transactionID)
    }

    func savePendingTransaction(_ transaction: TransactionData) {
        savePendingCallCount += 1
        pendingTransactions.append(PendingTransaction(id: UUID(), transaction: transaction))
    }

    func fetchPendingTransactions() -> [PendingTransaction] {
        return pendingTransactions
    }

    func removePendingTransaction(id: UUID) {
        removePendingCallCount += 1
        pendingTransactions.removeAll { $0.id == id }
    }

    var incrementRetryCallCount = 0
    func incrementRetryCount(id: UUID) {
        incrementRetryCallCount += 1
        if let index = pendingTransactions.firstIndex(where: { $0.id == id }) {
            var updated = pendingTransactions[index]
            updated.retryCount += 1
            pendingTransactions[index] = updated
        }
    }

    func reset() {
        handledTransactions.removeAll()
        pendingTransactions.removeAll()
        markCallCount = 0
        removeCallCount = 0
        isHandledCallCount = 0
        savePendingCallCount = 0
        removePendingCallCount = 0
    }
}
