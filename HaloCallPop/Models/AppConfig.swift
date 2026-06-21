import Foundation

struct AppConfig: Codable, Sendable, Equatable {
    var middlewareUrl: String
    var callpopApiSecret: String
    var allowedPopUrlHosts: [String]?

    static let defaultAllowedPopUrlHosts = ["halopsa.com"]

    var resolvedAllowedPopUrlHosts: [String] {
        allowedPopUrlHosts?.filter { !$0.isEmpty } ?? Self.defaultAllowedPopUrlHosts
    }

    func sanitizedForLogging() -> [String: String] {
        [
            "middlewareUrl": middlewareUrl,
            "callpopApiSecret": "<redacted>",
            "allowedPopUrlHosts": resolvedAllowedPopUrlHosts.joined(separator: ", ")
        ]
    }
}

struct DeviceRegistrationRequest: Codable, Sendable {
    let deviceId: String
    let platform: String
    let hostname: String
}

struct DeviceRegistrationResponse: Codable, Sendable {
    let ok: Bool
    let deviceId: String
    let deviceToken: String
    let wsUrl: String
}

enum WebSocketOutboundMessage: Encodable, Sendable {
    case pong(timestamp: String)
    case ack(callApiId: String)

    enum CodingKeys: String, CodingKey {
        case type
        case timestamp
        case callApiId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .pong(timestamp):
            try container.encode("pong", forKey: .type)
            try container.encode(timestamp, forKey: .timestamp)
        case let .ack(callApiId):
            try container.encode("ack", forKey: .type)
            try container.encode(callApiId, forKey: .callApiId)
        }
    }
}

struct WebSocketInboundMessage: Decodable, Sendable {
    let type: String
    let timestamp: String?
    let callApiId: String?
    let ticketId: Int?
    let popUrl: String?
    let callerNum: String?
    let callerName: String?
    let haloAgentId: Int?
    let voipnowExtension: String?
}

struct CallPopEvent: Sendable, Equatable {
    let callApiId: String
    let ticketId: Int
    let popUrl: String
    let callerNum: String?
    let callerName: String?
    let haloAgentId: Int?
    let voipnowExtension: String?
    let timestamp: String?

    init?(message: WebSocketInboundMessage) {
        guard message.type == "callpop",
              let callApiId = message.callApiId,
              let ticketId = message.ticketId,
              let popUrl = message.popUrl else {
            return nil
        }
        self.callApiId = callApiId
        self.ticketId = ticketId
        self.popUrl = popUrl
        self.callerNum = message.callerNum
        self.callerName = message.callerName
        self.haloAgentId = message.haloAgentId
        self.voipnowExtension = message.voipnowExtension
        self.timestamp = message.timestamp
    }

    func sanitizedForLogging() -> [String: String] {
        var fields: [String: String] = [
            "callApiId": callApiId,
            "ticketId": String(ticketId),
            "popUrlHost": URL(string: popUrl)?.host ?? "unknown"
        ]
        if let callerNum {
            fields["callerNum"] = callerNum
        }
        if let callerName {
            fields["callerName"] = callerName
        }
        if let haloAgentId {
            fields["haloAgentId"] = String(haloAgentId)
        }
        if let voipnowExtension {
            fields["voipnowExtension"] = voipnowExtension
        }
        if let timestamp {
            fields["timestamp"] = timestamp
        }
        return fields
    }
}
