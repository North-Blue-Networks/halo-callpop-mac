import AppKit
import Foundation

enum CLIArguments {
    static var isConnectOnly: Bool {
        CommandLine.arguments.contains("--connect-only")
    }
}

@MainActor
final class CallPopCoordinator: ObservableObject {
    @Published private(set) var deviceId: String = ""
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var lastError: String?

    private var webSocketManager: WebSocketManager?
    private var callPopProcessor: CallPopProcessor?
    private var wakeObserver: NSObjectProtocol?

    func start(connectOnly: Bool = false) {
        LoginItemManager.enableLaunchAtLogin()
        registerWakeHandler()

        Task {
            await bootstrap()
        }

        if connectOnly {
            LogManager.info("Running in connect-only debug mode")
        }
    }

    func stop() {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        webSocketManager?.disconnect()
    }

    func copyDeviceIdToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(deviceId, forType: .string)
        LogManager.info("Device ID copied to pasteboard")
    }

    func openLogs() {
        let logsDirectory = AppPaths.logsDirectory
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(logsDirectory)
    }

    private func bootstrap() async {
        do {
            let config = try ConfigManager.load()
            LogManager.info("Loaded config", metadata: config.sanitizedForLogging())

            let id = try DeviceIdentity.loadOrCreateDeviceId()
            deviceId = id

            callPopProcessor = CallPopProcessor(allowedHosts: config.resolvedAllowedPopUrlHosts)

            let registration = try await registerIfNeeded(config: config, deviceId: id)
            let wsURL = try WebSocketURLBuilder.build(middlewareUrl: config.middlewareUrl, wsPath: registration.wsUrl)

            let manager = WebSocketManager(
                onStateChange: { [weak self] state in
                    self?.connectionState = state
                },
                onCallPop: { [weak self] event in
                    await self?.handleCallPop(event)
                }
            )

            webSocketManager = manager
            manager.connect(to: wsURL)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            connectionState = .disconnected
            LogManager.error("Bootstrap failed", metadata: ["error": error.localizedDescription])
        }
    }

    private func registerIfNeeded(config: AppConfig, deviceId: String) async throws -> DeviceRegistrationResponse {
        LogManager.info("Registering device with middleware")
        let client = RegistrationClient()
        let response = try await client.register(
            config: config,
            deviceId: deviceId,
            hostname: DeviceIdentity.hostname
        )

        try KeychainStore.saveDeviceToken(response.deviceToken)
        LogManager.info("Device registered", metadata: ["deviceId": response.deviceId])
        return response
    }

    private func handleCallPop(_ event: CallPopEvent) async {
        guard let processor = callPopProcessor else { return }

        let result = await processor.process(event)

        if case let .opened(callApiId) = result {
            do {
                try await webSocketManager?.send(.ack(callApiId: callApiId))
                LogManager.info("Sent callpop ack", metadata: ["callApiId": callApiId])
            } catch {
                LogManager.error("Failed to send ack", metadata: ["error": error.localizedDescription])
            }
        }
    }

    private func registerWakeHandler() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                LogManager.info("System wake detected — reconnecting WebSocket")
                self?.webSocketManager?.reconnectNow()
            }
        }
    }
}
