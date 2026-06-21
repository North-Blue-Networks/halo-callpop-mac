import AppKit
import Foundation

enum BrowserLauncher {
    @MainActor
    static func open(urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            LogManager.error("Invalid pop URL", metadata: ["reason": "malformed URL"])
            return false
        }
        let opened = NSWorkspace.shared.open(url)
        if opened {
            LogManager.info("Opened pop URL in default browser", metadata: ["host": url.host ?? "unknown"])
        } else {
            LogManager.error("Failed to open pop URL", metadata: ["host": url.host ?? "unknown"])
        }
        return opened
    }
}

struct CallPopProcessor: Sendable {
    let deduplicator: CallPopDeduplicator
    let allowedHosts: [String]

    init(allowedHosts: [String], deduplicator: CallPopDeduplicator = CallPopDeduplicator()) {
        self.allowedHosts = allowedHosts
        self.deduplicator = deduplicator
    }

    func process(_ event: CallPopEvent) async -> CallPopProcessResult {
        guard await deduplicator.shouldProcess(callApiId: event.callApiId) else {
            LogManager.info("Ignored duplicate callpop", metadata: ["callApiId": event.callApiId])
            return .duplicateIgnored
        }

        LogManager.info("Received callpop", metadata: event.sanitizedForLogging())

        guard URLHostValidator.isAllowed(urlString: event.popUrl, allowedHosts: allowedHosts) else {
            LogManager.error(
                "Blocked pop URL — host not in allowlist",
                metadata: [
                    "callApiId": event.callApiId,
                    "popUrlHost": URL(string: event.popUrl)?.host ?? "unknown"
                ]
            )
            return .blockedInvalidHost
        }

        let opened = await BrowserLauncher.open(urlString: event.popUrl)
        return opened ? .opened(event.callApiId) : .openFailed
    }

    enum CallPopProcessResult: Equatable, Sendable {
        case opened(String)
        case duplicateIgnored
        case blockedInvalidHost
        case openFailed
    }
}
