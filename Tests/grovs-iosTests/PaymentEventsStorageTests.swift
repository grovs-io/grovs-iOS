import XCTest
@testable import Grovs

final class PaymentEventsStorageTests: XCTestCase {

    private var storage: PaymentEventsStorage!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        storage = PaymentEventsStorage(defaults: defaults)
    }

    override func tearDown() {
        storage = nil
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - markTransactionAsHandled + isTransactionHandled

    func testMarkTransactionAsHandledThenIsHandledReturnsTrue() {
        storage.markTransactionAsHandled(transactionID: 99001)

        XCTAssertTrue(storage.isTransactionHandled(transactionID: 99001))
    }

    func testIsTransactionHandledReturnsFalseForUnhandledID() {
        XCTAssertFalse(storage.isTransactionHandled(transactionID: 99999))
    }

    func testIsTransactionHandledReturnsFalseForNilID() {
        XCTAssertFalse(storage.isTransactionHandled(transactionID: nil))
    }

    // MARK: - removeEvent

    func testRemoveEventRemovesPreviouslyHandledTransaction() {
        storage.markTransactionAsHandled(transactionID: 99002)
        XCTAssertTrue(storage.isTransactionHandled(transactionID: 99002))

        storage.removeEvent(transactionID: 99002)
        XCTAssertFalse(storage.isTransactionHandled(transactionID: 99002))
    }

    func testRemoveEventForNonExistentIDDoesNotCrash() {
        // Should not throw or crash
        storage.removeEvent(transactionID: 99999)
        XCTAssertFalse(storage.isTransactionHandled(transactionID: 99999))
    }

    // MARK: - Idempotency

    func testMarkTransactionAsHandledIsIdempotent() {
        storage.markTransactionAsHandled(transactionID: 99003)
        storage.markTransactionAsHandled(transactionID: 99003)

        XCTAssertTrue(storage.isTransactionHandled(transactionID: 99003))

        // Remove once — should be gone (not duplicated)
        storage.removeEvent(transactionID: 99003)
        XCTAssertFalse(storage.isTransactionHandled(transactionID: 99003),
                       "Double-marking should not duplicate; single remove should clear it")
    }

    // MARK: - Migration

    func testMigrationFromDataCacheMovesIDs() {
        let migrationSuite = "migration-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: migrationSuite)!
        defer { UserDefaults().removePersistentDomain(forName: migrationSuite) }

        // Write IDs to legacy DataCache location
        let legacyCache = DataCache(name: "grovs-payment-events-cache")
        let legacyIDs: [UInt64] = [100, 200, 300]
        legacyCache.writeSync(array: legacyIDs, forKey: "handled-transaction-ids")

        // Create fresh storage — migration should run
        let migratedStorage = PaymentEventsStorage(defaults: defaults)

        XCTAssertTrue(migratedStorage.isTransactionHandled(transactionID: 100))
        XCTAssertTrue(migratedStorage.isTransactionHandled(transactionID: 200))
        XCTAssertTrue(migratedStorage.isTransactionHandled(transactionID: 300))
        XCTAssertFalse(migratedStorage.isTransactionHandled(transactionID: 999))

        // Clean up legacy cache
        legacyCache.cleanAll()
    }

    func testMigrationIsIdempotent() {
        let migrationSuite = "idempotent-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: migrationSuite)!
        defer { UserDefaults().removePersistentDomain(forName: migrationSuite) }

        // First migration
        let legacyCache = DataCache(name: "grovs-payment-events-cache")
        legacyCache.writeSync(array: [UInt64(100)] as [UInt64], forKey: "handled-transaction-ids")
        let storage1 = PaymentEventsStorage(defaults: defaults)
        XCTAssertTrue(storage1.isTransactionHandled(transactionID: 100))

        // Add a new ID after migration
        storage1.markTransactionAsHandled(transactionID: 500)

        // Create fresh storage — should not lose ID 500
        let storage2 = PaymentEventsStorage(defaults: defaults)
        XCTAssertTrue(storage2.isTransactionHandled(transactionID: 100))
        XCTAssertTrue(storage2.isTransactionHandled(transactionID: 500),
                      "ID added after first migration should survive second init")

        legacyCache.cleanAll()
    }

    func testMigrationWithEmptyLegacyCacheDoesNotCrash() {
        let migrationSuite = "empty-legacy-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: migrationSuite)!
        defer { UserDefaults().removePersistentDomain(forName: migrationSuite) }

        // No legacy data at all — should not crash
        let migratedStorage = PaymentEventsStorage(defaults: defaults)
        XCTAssertFalse(migratedStorage.isTransactionHandled(transactionID: 1))
    }

    // MARK: - Concurrency

    func testConcurrentMarkAndCheckDoesNotLoseData() {
        let concSuite = "conc-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: concSuite)!
        defer { UserDefaults().removePersistentDomain(forName: concSuite) }
        let concStorage = PaymentEventsStorage(defaults: defaults)

        let group = DispatchGroup()
        let count: UInt64 = 100

        // Mark transactions from multiple threads
        for i: UInt64 in 0..<count {
            group.enter()
            DispatchQueue.global().async {
                concStorage.markTransactionAsHandled(transactionID: i)
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 15)
        XCTAssertEqual(result, .success, "All concurrent marks should complete")

        // Verify all are handled
        for i: UInt64 in 0..<count {
            XCTAssertTrue(concStorage.isTransactionHandled(transactionID: i),
                         "Transaction \(i) should be marked after concurrent writes")
        }
    }

    // MARK: - Multiple transactions

    func testMultipleTransactionsAreIndependent() {
        storage.markTransactionAsHandled(transactionID: 99001)
        storage.markTransactionAsHandled(transactionID: 99002)

        XCTAssertTrue(storage.isTransactionHandled(transactionID: 99001))
        XCTAssertTrue(storage.isTransactionHandled(transactionID: 99002))

        storage.removeEvent(transactionID: 99001)

        XCTAssertFalse(storage.isTransactionHandled(transactionID: 99001),
                       "Removed transaction should no longer be handled")
        XCTAssertTrue(storage.isTransactionHandled(transactionID: 99002),
                      "Other transaction should be unaffected")
    }
}
