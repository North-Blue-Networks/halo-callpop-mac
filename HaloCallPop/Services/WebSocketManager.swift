import Foundation

@MainActor
final class WebSocketManager: NSObject {
    private let onStateChange: @MainActor (ConnectionState) -> Void
    private let onCallPop: @MainActor (CallPopEvent) async -> Void

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?

    private var webSocketURL: URL?
    private var shouldStayConnected = false
    private var reconnectAttempt = 0

    private let minReconnectDelay: TimeInterval = 5
    private let maxReconnectDelay: TimeInterval = 300

    init(
        onStateChange: @escaping @MainActor (ConnectionState) -> Void,
        onCallPop: @escaping @MainActor (CallPopEvent) async -> Void
    ) {
        self.onStateChange = onStateChange
        self.onCallPop = onCallPop
        super.init()
    }

    func connect(to url: URL) {
        shouldStayConnected = true
        webSocketURL = url
        reconnectAttempt = 0
        establishConnection(state: .connecting)
    }

    func disconnect() {
        shouldStayConnected = false
        reconnectTask?.cancel()
        pingTask?.cancel()
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        onStateChange(.disconnected)
    }

    func reconnectNow() {
        guard shouldStayConnected, webSocketURL != nil else { return }
        reconnectAttempt = 0
        establishConnection(state: .reconnecting)
    }

    func send(_ message: WebSocketOutboundMessage) async throws {
        guard let webSocketTask else {
            throw WebSocketError.notConnected
        }

        let data = try JSONEncoder().encode(message)
        guard let text = String(data: data, encoding: .utf8) else {
            throw WebSocketError.encodingFailed
        }
        try await webSocketTask.send(.string(text))
    }

    private func establishConnection(state: ConnectionState) {
        reconnectTask?.cancel()
        pingTask?.cancel()
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)

        guard let webSocketURL else { return }

        onStateChange(state)

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        urlSession = session
        let task = session.webSocketTask(with: webSocketURL)
        webSocketTask = task
        task.resume()

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            guard let webSocketTask else { return }

            do {
                let message = try await webSocketTask.receive()
                try await handle(message)
            } catch {
                if Task.isCancelled || !shouldStayConnected {
                    return
                }
                LogManager.warning("WebSocket receive failed", metadata: ["error": error.localizedDescription])
                scheduleReconnect()
                return
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) async throws {
        let text: String
        switch message {
        case let .string(value):
            text = value
        case let .data(data):
            guard let value = String(data: data, encoding: .utf8) else { return }
            text = value
        @unknown default:
            return
        }

        let inbound = try JSONDecoder().decode(WebSocketInboundMessage.self, from: Data(text.utf8))

        switch inbound.type {
        case "ping":
            let timestamp = ISO8601DateFormatter().string(from: Date())
            try await send(.pong(timestamp: timestamp))
        case "callpop":
            if let event = CallPopEvent(message: inbound) {
                await onCallPop(event)
            } else {
                LogManager.warning("Received malformed callpop message")
            }
        default:
            LogManager.info("Ignored unknown WebSocket message type", metadata: ["type": inbound.type])
        }
    }

    private func scheduleReconnect() {
        guard shouldStayConnected, webSocketURL != nil else { return }

        reconnectTask?.cancel()
        onStateChange(.reconnecting)

        let delay = min(maxReconnectDelay, minReconnectDelay * pow(2.0, Double(reconnectAttempt)))
        reconnectAttempt += 1

        LogManager.info("Scheduling WebSocket reconnect", metadata: ["delaySeconds": String(format: "%.0f", delay)])

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.establishConnection(state: .reconnecting)
        }
    }

    enum WebSocketError: LocalizedError {
        case notConnected
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "WebSocket is not connected"
            case .encodingFailed:
                return "Failed to encode WebSocket message"
            }
        }
    }
}

extension WebSocketManager: URLSessionWebSocketDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor in
            reconnectAttempt = 0
            onStateChange(.connected)
            LogManager.info("WebSocket connected")
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Task { @MainActor in
            LogManager.warning("WebSocket closed", metadata: ["closeCode": String(closeCode.rawValue)])
            if shouldStayConnected {
                scheduleReconnect()
            } else {
                onStateChange(.disconnected)
            }
        }
    }
}
