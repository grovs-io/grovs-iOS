import Foundation

/// A pending custom purchase awaiting retry.
struct PendingTransaction: Codable {
    let id: UUID
    let transaction: TransactionData
    var retryCount: Int = 0
}

/// Protocol defining the payment events storage interface.
protocol PaymentEventsStorageProtocol {
    func markTransactionAsHandled(transactionID: UInt64)
    func removeEvent(transactionID: UInt64)
    func isTransactionHandled(transactionID: UInt64?) -> Bool

    func savePendingTransaction(_ transaction: TransactionData)
    func fetchPendingTransactions() -> [PendingTransaction]
    func removePendingTransaction(id: UUID)
    func incrementRetryCount(id: UUID)
}

/// A class responsible for storing and managing payment transaction events.
/// Uses UserDefaults for persistent storage that survives cache purges and has no TTL.
class PaymentEventsStorage: PaymentEventsStorageProtocol {

    // MARK: - Constants

    /// Constants used within the class.
    private struct Constants {
        static let userDefaultsKey = "com.grovs.handled-transaction-ids"
        static let migrationDoneKey = "com.grovs.payment-storage-migrated"
        static let pendingTransactionsKey = "com.grovs.pending-transactions"
        static let legacyCacheName = "grovs-payment-events-cache"
        static let legacyCacheKey = "handled-transaction-ids"
    }

    // MARK: - Properties

    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "com.grovs.paymentEventsStorage")

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateFromDataCacheIfNeeded()
    }

    // MARK: - Public Methods

    /// Marks a transaction as handled by adding its ID to the storage.
    /// If the transaction ID already exists, it will not be added again.
    ///
    /// - Parameter transactionID: The ID of the transaction to mark as handled.
    func markTransactionAsHandled(transactionID: UInt64) {
        queue.sync {
            var existingTransactionIDs = fetchHandledTransactionIDs()

            if !existingTransactionIDs.contains(transactionID) {
                existingTransactionIDs.insert(transactionID)
                saveHandledTransactionIDs(existingTransactionIDs)
            }
        }
    }

    /// Removes a transaction from the list of handled transactions.
    ///
    /// - Parameter transactionID: The ID of the transaction to remove.
    func removeEvent(transactionID: UInt64) {
        queue.sync {
            var existingTransactionIDs = fetchHandledTransactionIDs()
            existingTransactionIDs.remove(transactionID)
            saveHandledTransactionIDs(existingTransactionIDs)
        }
    }

    /// Checks if a transaction has already been handled.
    ///
    /// - Parameter transactionID: The ID of the transaction to check.
    /// - Returns: A boolean value indicating whether the transaction has been handled.
    func isTransactionHandled(transactionID: UInt64?) -> Bool {
        queue.sync {
            guard let transactionID else {
                return false
            }

            return fetchHandledTransactionIDs().contains(transactionID)
        }
    }

    // MARK: - Pending Transactions

    func savePendingTransaction(_ transaction: TransactionData) {
        queue.sync {
            var pending = _fetchPendingTransactions()
            pending.append(PendingTransaction(id: UUID(), transaction: transaction))
            savePendingTransactions(pending)
        }
    }

    func fetchPendingTransactions() -> [PendingTransaction] {
        queue.sync {
            _fetchPendingTransactions()
        }
    }

    func removePendingTransaction(id: UUID) {
        queue.sync {
            var pending = _fetchPendingTransactions()
            pending.removeAll { $0.id == id }
            savePendingTransactions(pending)
        }
    }

    func incrementRetryCount(id: UUID) {
        queue.sync {
            var pending = _fetchPendingTransactions()
            if let index = pending.firstIndex(where: { $0.id == id }) {
                pending[index].retryCount += 1
                savePendingTransactions(pending)
            }
        }
    }

    /// Internal fetch — must be called within `queue`.
    private func _fetchPendingTransactions() -> [PendingTransaction] {
        guard let data = defaults.data(forKey: Constants.pendingTransactionsKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([PendingTransaction].self, from: data)
        } catch {
            DebugLogger.shared.log(.error, "Failed to decode pending transactions: \(error.localizedDescription)")
            return []
        }
    }

    private func savePendingTransactions(_ pending: [PendingTransaction]) {
        do {
            let data = try JSONEncoder().encode(pending)
            defaults.set(data, forKey: Constants.pendingTransactionsKey)
        } catch {
            DebugLogger.shared.log(.error, "Failed to encode pending transactions: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func fetchHandledTransactionIDs() -> Set<UInt64> {
        guard let array = defaults.object(forKey: Constants.userDefaultsKey) as? [UInt64] else {
            return []
        }
        return Set(array)
    }

    private func saveHandledTransactionIDs(_ transactionIDs: Set<UInt64>) {
        defaults.set(Array(transactionIDs), forKey: Constants.userDefaultsKey)
    }

    /// One-time migration from the old DataCache-backed storage to UserDefaults.
    /// Prevents a mass re-report of historical transactions on the first launch after update.
    private func migrateFromDataCacheIfNeeded() {
        queue.sync {
            guard !defaults.bool(forKey: Constants.migrationDoneKey) else { return }
            defer { defaults.set(true, forKey: Constants.migrationDoneKey) }

            let legacyCache = DataCache(name: Constants.legacyCacheName)
            guard let legacyIDs = legacyCache.readArray(forKey: Constants.legacyCacheKey) as? [UInt64], !legacyIDs.isEmpty else {
                return
            }

            // Merge legacy IDs with any that may already exist in UserDefaults
            var current = fetchHandledTransactionIDs()
            current.formUnion(legacyIDs)
            saveHandledTransactionIDs(current)

            // Clean up the old cache entry
            legacyCache.clean(byKey: Constants.legacyCacheKey)
        }
    }
}
