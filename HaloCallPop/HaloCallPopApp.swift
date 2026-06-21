import SwiftUI

@main
struct HaloCallPopApp: App {
    @StateObject private var coordinator = CallPopCoordinator()

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenuView()
                .environmentObject(coordinator)
                .onAppear {
                    coordinator.start(connectOnly: CLIArguments.isConnectOnly)
                }
        } label: {
            MenuBarIconView(connectionState: coordinator.connectionState)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarIconView: View {
    let connectionState: ConnectionState

    var body: some View {
        Image(systemName: "phone.connection")
            .symbolRenderingMode(.palette)
            .foregroundStyle(statusColor, .primary)
            .accessibilityLabel("Halo Call Pop — \(connectionState.statusLabel)")
    }

    private var statusColor: Color {
        switch connectionState {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .orange
        case .disconnected:
            return .red
        }
    }
}

struct MenuBarMenuView: View {
    @EnvironmentObject private var coordinator: CallPopCoordinator
    @Environment(\.openURL) private var openURL

    var body: some View {
        Text("Halo Call Pop")
            .font(.headline)

        Divider()

        Button("Copy Device ID") {
            coordinator.copyDeviceIdToPasteboard()
        }

        Text("Device ID: \(coordinator.deviceId)")
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)

        Text("Status: \(coordinator.connectionState.statusLabel)")
            .foregroundStyle(statusColor)

        if let lastError = coordinator.lastError {
            Text(lastError)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(3)
        }

        Divider()

        Button("Open Logs") {
            coordinator.openLogs()
        }

        Button("Quit") {
            coordinator.stop()
            NSApplication.shared.terminate(nil)
        }
    }

    private var statusColor: Color {
        switch coordinator.connectionState {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .orange
        case .disconnected:
            return .red
        }
    }
}
