import Foundation
import XCTest
@testable import HaloCallPop

final class MessageParsingTests: XCTestCase {
    func testParsesCallPopMessage() throws {
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
        XCTAssertEqual(message.type, "callpop")
        XCTAssertEqual(message.callApiId, "abc-123")
        XCTAssertEqual(message.ticketId, 12345)

        let event = try XCTUnwrap(CallPopEvent(message: message))
        XCTAssertEqual(event.callApiId, "abc-123")
        XCTAssertEqual(event.ticketId, 12345)
        XCTAssertTrue(event.popUrl.contains("halopsa.com"))
        XCTAssertEqual(event.callerNum, "+15551234567")
        XCTAssertEqual(event.callerName, "Jane Doe")
        XCTAssertEqual(event.haloAgentId, 42)
        XCTAssertEqual(event.voipnowExtension, "0003*201")
    }

    func testRejectsIncompleteCallPopMessage() throws {
        let json = """
        {
          "type": "callpop",
          "callApiId": "abc-123"
        }
        """

        let message = try JSONDecoder().decode(WebSocketInboundMessage.self, from: Data(json.utf8))
        XCTAssertNil(CallPopEvent(message: message))
    }

    func testEncodesOutboundMessages() throws {
        let pongData = try JSONEncoder().encode(WebSocketOutboundMessage.pong(timestamp: "2026-06-21T10:00:00Z"))
        let pong = try XCTUnwrap(String(data: pongData, encoding: .utf8))
        XCTAssertTrue(pong.contains("\"type\":\"pong\""))
        XCTAssertTrue(pong.contains("2026-06-21T10:00:00Z"))

        let ackData = try JSONEncoder().encode(WebSocketOutboundMessage.ack(callApiId: "abc-123"))
        let ack = try XCTUnwrap(String(data: ackData, encoding: .utf8))
        XCTAssertTrue(ack.contains("\"type\":\"ack\""))
        XCTAssertTrue(ack.contains("abc-123"))
    }

    func testParsesRegistrationResponse() throws {
        let json = """
        {
          "ok": true,
          "deviceId": "11111111-2222-3333-4444-555555555555",
          "deviceToken": "secret-token",
          "wsUrl": "/agents/ws/callpop?deviceToken=secret-token"
        }
        """

        let response = try JSONDecoder().decode(DeviceRegistrationResponse.self, from: Data(json.utf8))
        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.deviceId, "11111111-2222-3333-4444-555555555555")
        XCTAssertTrue(response.wsUrl.hasPrefix("/agents/ws/callpop"))
    }

    func testParsesAppConfigWithDefaultAllowlist() throws {
        let json = """
        {
          "middlewareUrl": "https://example.up.railway.app",
          "callpopApiSecret": "test-secret"
        }
        """

        let config = try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))
        XCTAssertTrue(config.middlewareUrl.contains("railway.app"))
        XCTAssertEqual(config.resolvedAllowedPopUrlHosts, ["halopsa.com"])
    }
}
