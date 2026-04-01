import XCTest
@testable import Grovs

final class MD5Tests: XCTestCase {

    func testMD5EmptyString() {
        XCTAssertEqual("".md5, "d41d8cd98f00b204e9800998ecf8427e")
    }

    func testMD5Hello() {
        XCTAssertEqual("hello".md5, "5d41402abc4b2a76b9719d911017c592")
    }

    func testMD5LongerString() {
        XCTAssertEqual(
            "The quick brown fox jumps over the lazy dog".md5,
            "9e107d9d372bb6826bd81d3542a419d6"
        )
    }
}
