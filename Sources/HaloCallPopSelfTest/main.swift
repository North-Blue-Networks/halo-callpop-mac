import Foundation
@testable import HaloCallPop

var failures = 0

func expect(_ condition: Bool, _ message: String, file: StaticString = #file, line: UInt = #line) {
    if !condition {
        failures += 1
        fputs("FAIL: \(message) (\(file):\(line))\n", stderr)
    }
}

func expectEqual<T: Equatable>(_ lhs: T, _ rhs: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if lhs != rhs {
        failures += 1
        fputs("FAIL: expected \(rhs), got \(lhs) \(message) (\(file):\(line))\n", stderr)
    }
}

func testMessageParsing() throws {
    let json = """
    {
      "type": "callpop",
      "callApiId": "abc-123",
      "ticketId": 12345,
      "popUrl": "https://tenant.halopsa.com/agent/ticket?id=12345",
      "callerNum": "+15551234567",
      "callerName": "Jane Doe",
      "haloAgentId": 42,
      "voipnowExtension": "0003*201",
      "timestamp": "2026-06-21T10:00:00Z"
    }
    """

    let message = try JSONDecoder().decode(WebSocketInboundMessage.self, from: Data(json.utf8))
    expectEqual(message.type, "callpop")
    expectEqual(message.callApiId, "abc-123")
    expect(message.ticketId == 12345, "ticketId should parse")

    let event = CallPopEvent(message: message)
    expect(event != nil, "callpop event should parse")
    expectEqual(event?.callApiId, "abc-123")
}

func testIncompleteMessageRejected() throws {
    let json = """
    { "type": "callpop", "callApiId": "abc-123" }
    """
    let message = try JSONDecoder().decode(WebSocketInboundMessage.self, from: Data(json.utf8))
    expect(CallPopEvent(message: message) == nil, "incomplete callpop should be rejected")
}

func testOutboundEncoding() throws {
    let pongData = try JSONEncoder().encode(WebSocketOutboundMessage.pong(timestamp: "2026-06-21T10:00:00Z"))
    let pong = String(data: pongData, encoding: .utf8) ?? ""
    expect(pong.contains("\"type\":\"pong\""), "pong type")
    expect(pong.contains("2026-06-21T10:00:00Z"), "pong timestamp")

    let ackData = try JSONEncoder().encode(WebSocketOutboundMessage.ack(callApiId: "abc-123"))
    let ack = String(data: ackData, encoding: .utf8) ?? ""
    expect(ack.contains("\"type\":\"ack\""), "ack type")
    expect(ack.contains("abc-123"), "ack callApiId")
}

func testDeduplication() async {
    let deduplicator = CallPopDeduplicator(window: 60)
    let now = Date(timeIntervalSince1970: 1_000_000)

    expect(await deduplicator.shouldProcess(callApiId: "call-1", now: now), "first call should process")
    expect(await !deduplicator.shouldProcess(callApiId: "call-1", now: now.addingTimeInterval(10)), "duplicate should be ignored")
    expect(await deduplicator.shouldProcess(callApiId: "call-2", now: now.addingTimeInterval(10)), "different call should process")
    expect(await deduplicator.shouldProcess(callApiId: "call-1", now: now.addingTimeInterval(61)), "call after window should process")
}

func testURLValidation() {
    expect(URLHostValidator.isAllowed(
        urlString: "https://tenant.halopsa.com/agent/ticket?id=1",
        allowedHosts: ["halopsa.com"]
    ), "halopsa host allowed")

    expect(!URLHostValidator.isAllowed(
        urlString: "http://tenant.halopsa.com/agent/ticket?id=1",
        allowedHosts: ["halopsa.com"]
    ), "http blocked")

    expect(!URLHostValidator.isAllowed(
        urlString: "https://evil.example.com/agent/ticket?id=1",
        allowedHosts: ["halopsa.com"]
    ), "unknown host blocked")
}

func testWebSocketURLBuilder() throws {
    let url = try WebSocketURLBuilder.build(
        middlewareUrl: "https://example.up.railway.app",
        wsPath: "/agents/ws/callpop?deviceToken=abc"
    )
    expectEqual(url.scheme, "wss")
    expectEqual(url.host, "example.up.railway.app")
    expectEqual(url.path, "/agents/ws/callpop")
    expect(url.query?.contains("deviceToken=abc") == true, "query should include token")
}

@main
struct HaloCallPopSelfTest {
    static func main() async {
        do {
            try testMessageParsing()
            try testIncompleteMessageRejected()
            try testOutboundEncoding()
            await testDeduplication()
            testURLValidation()
            try testWebSocketURLBuilder()
        } catch {
            failures += 1
            fputs("FAIL: thrown error: \(error)\n", stderr)
        }

        if failures == 0 {
            print("All HaloCallPop self-tests passed.")
        } else {
            fputs("\(failures) test(s) failed.\n", stderr)
            exit(1)
        }
    }
}
