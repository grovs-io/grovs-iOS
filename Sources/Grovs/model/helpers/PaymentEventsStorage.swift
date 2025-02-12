import Foundation

/// A class responsible for storing and managing payment transaction events.
class PaymentEventsStorage {

    // MARK: - Constants

    /// Constants used within the class.
    private struct Constants {
        static let handledTransactionIDs = "handled-transaction-ids"
    }

    // MARK: - Properties

    /// The data cache instance used for storing events.
    private let dataCache = DataCache(name: "grovs-payment-events-cache")


    // MARK: - Public Methods

    /// Marks a transaction as handled by adding its ID to the storage.
    /// If the transaction ID already exists, it will not be added again.
    ///
    /// - Parameter transactionID: The ID of the transaction to mark as handled.
    func markTransactionAsHandled(transactionID: UInt64) {
        // Retrieve the existing transaction IDs from the cache
        var existingTransactionIDs = fetchHandledTransactionIDs()

        // Add the transaction ID if it isn't already marked
        if !existingTransactionIDs.contains(transactionID) {
            existingTransactionIDs.append(transactionID)
            // Write the updated transaction IDs back to cache
            saveHandledTransactionIDs(existingTransactionIDs)
        }
    }

    /// Removes a transaction from the list of handled transactions.
    ///
    /// - Parameter transactionID: The ID of the transaction to remove.
    func removeEvent(transactionID: UInt64) {
        // Retrieve the existing transaction IDs from the cache
        var existingTransactionIDs = fetchHandledTransactionIDs()

        // Remove the specified transaction ID
        existingTransactionIDs.removeAll(where: { $0 == transactionID })

        // Write the updated transaction IDs back to cache
        saveHandledTransactionIDs(existingTransactionIDs)
    }

    /// Checks if a transaction has already been handled.
    ///
    /// - Parameter transactionID: The ID of the transaction to check.
    /// - Returns: A boolean value indicating whether the transaction has been handled.
    func isTransactionHandled(transactionID: UInt64?) -> Bool {
        guard let transactionID else {
            return false
        }

        let existingTransactionIDs = fetchHandledTransactionIDs()
        return existingTransactionIDs.contains(transactionID)
    }

    // MARK: - Private Methods

    /// Fetches the list of handled transaction IDs from the cache.
    ///
    /// - Returns: An array of handled transaction IDs.
    private func fetchHandledTransactionIDs() -> [UInt64] {
        // Read the array of handled transaction IDs from cache
        guard let storedTransactionIDs = dataCache.readArray(forKey: Constants.handledTransactionIDs) as? [UInt64] else {
            return []  // If no data exists, return an empty array
        }
        return storedTransactionIDs
    }

    /// Saves the list of handled transaction IDs to the cache, ensuring they are unique.
    ///
    /// - Parameter transactionIDs: The array of transaction IDs to save.
    private func saveHandledTransactionIDs(_ transactionIDs: [UInt64]) {
        // Remove duplicates by using a Set, then convert it back to an array
        let uniqueTransactionIDs = Array(Set(transactionIDs))

        // Write the unique transaction IDs back to cache
        dataCache.write(array: uniqueTransactionIDs, forKey: Constants.handledTransactionIDs)
    }
}
