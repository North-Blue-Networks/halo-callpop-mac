import Foundation

enum DeviceIdentity {
    static func loadOrCreateDeviceId() throws -> String {
        try FileManager.default.createDirectory(at: AppPaths.appSupportDirectory, withIntermediateDirectories: true)

        if let existing = try? String(contentsOf: AppPaths.deviceIdURL, encoding: .utf8) {
            let trimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
            if UUID(uuidString: trimmed) != nil {
                return trimmed
            }
        }

        let newId = UUID().uuidString.lowercased()
        try newId.write(to: AppPaths.deviceIdURL, atomically: true, encoding: .utf8)
        LogManager.info("Generated new device ID")
        return newId
    }

    static var hostname: String {
        Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    }
}
