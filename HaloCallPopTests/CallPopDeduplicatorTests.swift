import Foundation
import XCTest
@testable import HaloCallPop

final class CallPopDeduplicatorTests: XCTestCase {
    func testDeduplicatesWithinWindow() async {
        let deduplicator = CallPopDeduplicator(window: 60)
        let now = Date(timeIntervalSince1970: 1_000_000)

        let first = await deduplicator.shouldProcess(callApiId: "call-1", now: now)
        let duplicate = await deduplicator.shouldProcess(callApiId: "call-1", now: now.addingTimeInterval(10))
        let different = await deduplicator.shouldProcess(callApiId: "call-2", now: now.addingTimeInterval(10))

        XCTAssertTrue(first)
        XCTAssertFalse(duplicate)
        XCTAssertTrue(different)
    }

    func testAllowsSameCallApiIdAfterWindowExpires() async {
        let deduplicator = CallPopDeduplicator(window: 60)
        let start = Date(timeIntervalSince1970: 2_000_000)

        XCTAssertTrue(await deduplicator.shouldProcess(callApiId: "call-1", now: start))
        XCTAssertFalse(await deduplicator.shouldProcess(callApiId: "call-1", now: start.addingTimeInterval(30)))
        XCTAssertTrue(await deduplicator.shouldProcess(callApiId: "call-1", now: start.addingTimeInterval(61)))
    }
}

final class URLHostValidatorTests: XCTestCase {
    func testAllowsHalopsaHosts() {
        XCTAssertTrue(URLHostValidator.isAllowed(
            urlString: "https://tenant.halopsa.com/agent/ticket?id=1",
            allowedHosts: ["halopsa.com"]
        ))
        XCTAssertTrue(URLHostValidator.isAllowed(
            urlString: "https://northblue.halopsa.com/agent/ticket?id=1",
            allowedHosts: ["*.halopsa.com"]
        ))
    }

    func testBlocksInvalidHosts() {
        XCTAssertFalse(URLHostValidator.isAllowed(
            urlString: "http://tenant.halopsa.com/agent/ticket?id=1",
            allowedHosts: ["halopsa.com"]
        ))
        XCTAssertFalse(URLHostValidator.isAllowed(
            urlString: "https://evil.example.com/agent/ticket?id=1",
            allowedHosts: ["halopsa.com"]
        ))
    }
}

final class WebSocketURLBuilderTests: XCTestCase {
    func testBuildsFromWsPath() throws {
        let url = try WebSocketURLBuilder.build(
            middlewareUrl: "https://example.up.railway.app",
            wsPath: "/agents/ws/callpop?deviceToken=abc"
        )
        XCTAssertEqual(url.scheme, "wss")
        XCTAssertEqual(url.host, "example.up.railway.app")
        XCTAssertEqual(url.path, "/agents/ws/callpop")
        XCTAssertTrue(url.query?.contains("deviceToken=abc") == true)
    }
}
