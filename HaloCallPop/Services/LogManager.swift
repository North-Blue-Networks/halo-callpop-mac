import Foundation
import os

enum LogManager {
    private static let logger = Logger(subsystem: "com.northblue.halo-callpop", category: "app")

    static var logFileURL: URL {
        AppPaths.logsDirectory.appendingPathComponent("halo-callpop.log")
    }

    static func info(_ message: String, metadata: [String: String] = [:]) {
        log(level: .info, message: message, metadata: metadata)
    }

    static func warning(_ message: String, metadata: [String: String] = [:]) {
        log(level: .default, message: message, metadata: metadata)
    }

    static func error(_ message: String, metadata: [String: String] = [:]) {
        log(level: .error, message: message, metadata: metadata)
    }

    private static func log(level: OSLogType, message: String, metadata: [String: String]) {
        let sanitizedMetadata = metadata.mapValues { redactIfNeeded($0) }
        let metadataText = sanitizedMetadata.isEmpty
            ? ""
            : " " + sanitizedMetadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")

        let line = "[\(timestamp())] \(message)\(metadataText)\n"
        logger.log(level: level, "\(message, privacy: .public)\(metadataText, privacy: .public)")

        appendToFile(line)
    }

    private static func appendToFile(_ line: String) {
        do {
            try FileManager.default.createDirectory(at: AppPaths.logsDirectory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: logFileURL.path) {
                FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: logFileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            if let data = line.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
        } catch {
            logger.error("Failed to write log file: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func redactIfNeeded(_ value: String) -> String {
        let lowered = value.lowercased()
        if lowered.contains("secret")
            || lowered.contains("token")
            || lowered.contains("password")
            || lowered.contains("authorization") {
            return "<redacted>"
        }
        return value
    }
}

enum AppPaths {
    static let appSupportDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/NorthBlue/HaloCallPop", isDirectory: true)

    static let configURL = appSupportDirectory.appendingPathComponent("config.json")
    static let deviceIdURL = appSupportDirectory.appendingPathComponent("device-id.txt")
    static let logsDirectory = appSupportDirectory.appendingPathComponent("Logs", isDirectory: true)
}
