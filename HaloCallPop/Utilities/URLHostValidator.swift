import Foundation

enum URLHostValidator {
    static func isAllowed(urlString: String, allowedHosts: [String]) -> Bool {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased(),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" else {
            return false
        }

        return allowedHosts.contains { allowed in
            let normalized = allowed.lowercased()
            if normalized.hasPrefix("*.") {
                let suffix = String(normalized.dropFirst(2))
                return host == suffix || host.hasSuffix(".\(suffix)")
            }
            return host == normalized || host.hasSuffix(".\(normalized)")
        }
    }
}
