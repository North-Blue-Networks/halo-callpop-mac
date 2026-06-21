import Foundation

struct RegistrationClient: Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func register(config: AppConfig, deviceId: String, hostname: String) async throws -> DeviceRegistrationResponse {
        guard let baseURL = URL(string: config.middlewareUrl) else {
            throw RegistrationError.invalidMiddlewareURL
        }

        let url = baseURL.appendingPathComponent("agents/devices/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.callpopApiSecret, forHTTPHeaderField: "X-Callpop-Secret")

        let body = DeviceRegistrationRequest(deviceId: deviceId, platform: "mac", hostname: hostname)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RegistrationError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw RegistrationError.httpStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(DeviceRegistrationResponse.self, from: data)
        guard decoded.ok else {
            throw RegistrationError.registrationRejected
        }

        return decoded
    }

    enum RegistrationError: LocalizedError {
        case invalidMiddlewareURL
        case invalidResponse
        case httpStatus(Int)
        case registrationRejected

        var errorDescription: String? {
            switch self {
            case .invalidMiddlewareURL:
                return "Invalid middleware URL"
            case .invalidResponse:
                return "Invalid registration response"
            case let .httpStatus(code):
                return "Registration failed with HTTP \(code)"
            case .registrationRejected:
                return "Registration rejected by middleware"
            }
        }
    }
}
