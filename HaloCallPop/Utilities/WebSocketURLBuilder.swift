import Foundation

enum WebSocketURLBuilder {
    static func build(middlewareUrl: String, wsPath: String) throws -> URL {
        guard var components = URLComponents(string: middlewareUrl) else {
            throw BuildError.invalidMiddlewareURL
        }

        if wsPath.hasPrefix("ws") {
            guard let absolute = URL(string: wsPath) else {
                throw BuildError.invalidWsPath
            }
            return absolute
        }

        components.scheme = components.scheme == "https" ? "wss" : "ws"

        if wsPath.hasPrefix("/") {
            components.path = wsPath.split(separator: "?").first.map(String.init) ?? wsPath
            if let query = wsPath.split(separator: "?").dropFirst().first {
                components.percentEncodedQuery = String(query)
            }
        } else {
            components.path = "/\(wsPath)"
        }

        guard let url = components.url else {
            throw BuildError.invalidWsPath
        }
        return url
    }

    static func build(middlewareUrl: String, deviceToken: String) throws -> URL {
        guard var components = URLComponents(string: middlewareUrl) else {
            throw BuildError.invalidMiddlewareURL
        }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/agents/ws/callpop"
        components.queryItems = [URLQueryItem(name: "deviceToken", value: deviceToken)]
        guard let url = components.url else {
            throw BuildError.invalidWsPath
        }
        return url
    }

    enum BuildError: LocalizedError {
        case invalidMiddlewareURL
        case invalidWsPath

        var errorDescription: String? {
            switch self {
            case .invalidMiddlewareURL:
                return "Invalid middleware URL"
            case .invalidWsPath:
                return "Invalid WebSocket path"
            }
        }
    }
}
