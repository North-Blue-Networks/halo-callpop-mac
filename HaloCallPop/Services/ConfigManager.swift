import Foundation

enum ConfigManager {
    static func load() throws -> AppConfig {
        guard FileManager.default.fileExists(atPath: AppPaths.configURL.path) else {
            throw ConfigError.missingFile(AppPaths.configURL.path)
        }

        let data = try Data(contentsOf: AppPaths.configURL)
        let config = try JSONDecoder().decode(AppConfig.self, from: data)

        guard !config.middlewareUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConfigError.invalidValue("middlewareUrl must not be empty")
        }

        guard !config.callpopApiSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConfigError.invalidValue("callpopApiSecret must not be empty")
        }

        guard URL(string: config.middlewareUrl)?.host != nil else {
            throw ConfigError.invalidValue("middlewareUrl must be a valid URL")
        }

        return config
    }

    enum ConfigError: LocalizedError {
        case missingFile(String)
        case invalidValue(String)

        var errorDescription: String? {
            switch self {
            case let .missingFile(path):
                return "Config file not found at \(path)"
            case let .invalidValue(message):
                return message
            }
        }
    }
}
