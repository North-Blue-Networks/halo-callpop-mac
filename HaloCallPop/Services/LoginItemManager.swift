import Foundation
import ServiceManagement

enum LoginItemManager {
    static func enableLaunchAtLogin() {
        do {
            if #available(macOS 13.0, *) {
                let service = SMAppService.mainApp
                if service.status == .notRegistered {
                    try service.register()
                    LogManager.info("Registered launch at login")
                }
            }
        } catch {
            LogManager.error("Failed to register launch at login", metadata: ["error": error.localizedDescription])
        }
    }
}
