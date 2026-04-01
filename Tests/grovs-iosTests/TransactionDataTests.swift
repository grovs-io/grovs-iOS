import XCTest
@testable import Grovs

final class TransactionDataTests: XCTestCase {

    // MARK: - toData() key mapping

    func testToDataContainsAllKeysWithCorrectMapping() {
        let date = Date()
        let data = TransactionData(
            type: .buy,
            price: 999,
            transactionID: 123,
            oldTransactionID: 456,
            currency: "USD",
            productID: "com.app.product",
            bundleID: "com.app.bundle",
            startDate: date,
            store: true
        )

        let dict = data.toData()

        XCTAssertEqual(dict["event_type"] as? String, "buy")
        XCTAssertEqual(dict["price_cents"] as? Int, 999)
        XCTAssertEqual(dict["currency"] as? String, "USD")
        XCTAssertEqual(dict["transaction_id"] as? UInt64, 123)
        XCTAssertEqual(dict["original_transaction_id"] as? UInt64, 456)
        XCTAssertEqual(dict["product_id"] as? String, "com.app.product")
        XCTAssertEqual(dict["identifier"] as? String, "com.app.bundle")
        XCTAssertEqual(dict["store"] as? Bool, true)
        XCTAssertEqual(dict["date"] as? String, date.backendDateString())
    }

    func testToDataWithNilOptionals() {
        let data = TransactionData(
            type: .buy,
            price: nil,
            transactionID: nil,
            oldTransactionID: nil,
            currency: nil,
            productID: nil,
            bundleID: nil,
            startDate: nil,
            store: false
        )

        let dict = data.toData()

        XCTAssertEqual(dict["event_type"] as? String, "buy")
        XCTAssertEqual(dict["store"] as? Bool, false)

        assertValueIsNil(dict, key: "price_cents")
        assertValueIsNil(dict, key: "currency")
        assertValueIsNil(dict, key: "transaction_id")
        assertValueIsNil(dict, key: "original_transaction_id")
        assertValueIsNil(dict, key: "product_id")
        assertValueIsNil(dict, key: "identifier")
        assertValueIsNil(dict, key: "date")
    }

    // MARK: - TransactionType raw values

    func testTransactionTypeRawValues() {
        XCTAssertEqual(TransactionType.buy.rawValue, "buy")
        XCTAssertEqual(TransactionType.cancel.rawValue, "cancel")
        XCTAssertEqual(TransactionType.refund.rawValue, "refund")
    }

    // MARK: - Boundary values

    func testToDataWithZeroPriceAndEmptyStrings() {
        let data = TransactionData(
            type: .buy,
            price: 0,
            transactionID: 0,
            oldTransactionID: 0,
            currency: "",
            productID: "",
            bundleID: "",
            startDate: nil,
            store: false
        )

        let dict = data.toData()

        XCTAssertEqual(dict["price_cents"] as? Int, 0)
        XCTAssertEqual(dict["transaction_id"] as? UInt64, 0)
        XCTAssertEqual(dict["original_transaction_id"] as? UInt64, 0)
        XCTAssertEqual(dict["currency"] as? String, "")
        XCTAssertEqual(dict["product_id"] as? String, "")
        XCTAssertEqual(dict["identifier"] as? String, "")
    }

    func testToDataWithLargeValues() {
        let data = TransactionData(
            type: .refund,
            price: Int.max,
            transactionID: UInt64.max,
            oldTransactionID: UInt64.max,
            currency: "USD",
            productID: "prod",
            bundleID: "com.test",
            startDate: nil,
            store: true
        )

        let dict = data.toData()

        XCTAssertEqual(dict["price_cents"] as? Int, Int.max)
        XCTAssertEqual(dict["transaction_id"] as? UInt64, UInt64.max)
        XCTAssertEqual(dict["original_transaction_id"] as? UInt64, UInt64.max)
    }

    // MARK: - Date formatting

    func testToDataDateFormattingMatchesBackendDateString() {
        let date = Date()
        let data = TransactionData(
            type: .buy,
            price: nil,
            transactionID: nil,
            oldTransactionID: nil,
            currency: nil,
            productID: nil,
            bundleID: nil,
            startDate: date,
            store: true
        )

        let dict = data.toData()
        let dateString = dict["date"] as? String

        XCTAssertEqual(dateString, date.backendDateString())
    }
}
