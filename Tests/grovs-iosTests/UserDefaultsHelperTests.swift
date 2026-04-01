import XCTest
@testable import Grovs

final class UserDefaultsHelperTests: XCTestCase {

    override func setUp() {
        super.setUp()
        for key in [UserDefaultsKeys.grovsNumberOfOpens, .grovsResignTimestamp, .grovsLastStartTimestamp] {
            UserDefaultsHelper.remove(key: key)
        }
    }

    override func tearDown() {
        for key in [UserDefaultsKeys.grovsNumberOfOpens, .grovsResignTimestamp, .grovsLastStartTimestamp] {
            UserDefaultsHelper.remove(key: key)
        }
        super.tearDown()
    }

    // MARK: - Raw value stability
    // If someone renames these raw values, all persisted user data silently breaks.

    func testRawValuesAreStable() {
        XCTAssertEqual(UserDefaultsKeys.grovsNumberOfOpens.rawValue, "grovsNumberOfOpens")
        XCTAssertEqual(UserDefaultsKeys.grovsResignTimestamp.rawValue, "grovsResignTimestamp")
        XCTAssertEqual(UserDefaultsKeys.grovsLastStartTimestamp.rawValue, "grovsLastStartTimestamp")
    }

    // MARK: - Protocol conformance (instance delegates to static)
    // UserDefaultsHelper conforms to UserDefaultsHelperProtocol via instance methods
    // that call static methods. This is actual logic worth verifying.

    func testInstanceGetIntDelegatesToStatic() {
        UserDefaultsHelper.set(value: 77, key: .grovsNumberOfOpens)
        let helper = UserDefaultsHelper()
        let result = helper.getInt(key: .grovsNumberOfOpens)
        XCTAssertEqual(result, 77, "Instance getInt should read the same value written by static set")
    }

    func testInstanceSetIntDelegatesToStatic() {
        let helper = UserDefaultsHelper()
        helper.setInt(value: 88, key: .grovsNumberOfOpens)
        let result = UserDefaultsHelper.getInt(key: .grovsNumberOfOpens)
        XCTAssertEqual(result, 88, "Static getInt should read the value written by instance setInt")
    }

    // MARK: - containsItem vs remove interaction

    func testContainsItemReturnsFalseAfterRemove() {
        UserDefaultsHelper.set(value: 1, key: .grovsResignTimestamp)
        XCTAssertTrue(UserDefaultsHelper.containsItem(for: .grovsResignTimestamp))
        UserDefaultsHelper.remove(key: .grovsResignTimestamp)
        XCTAssertFalse(UserDefaultsHelper.containsItem(for: .grovsResignTimestamp),
                       "containsItem should return false after remove")
    }
}
