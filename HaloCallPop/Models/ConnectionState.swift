import Foundation

enum ConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting

    var statusLabel: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting…"
        case .connected:
            return "Connected"
        case .reconnecting:
            return "Reconnecting…"
        }
    }

    var isHealthy: Bool {
        self == .connected
    }

    var isWarning: Bool {
        self == .connecting || self == .reconnecting
    }
}
