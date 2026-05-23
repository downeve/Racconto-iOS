import Foundation
import KeychainAccess

@Observable
class RaccontoAPI {
    static let shared = RaccontoAPI()
    #if DEBUG
    static let baseURL = "http://localhost:8000"
    #else
    static let baseURL = "https://racconto.app/api"
    #endif
    private var baseURL: String { Self.baseURL }
    private let keychain = Keychain(service: "com.racconto.app")

    private var token: String? {
        get { try? keychain.get("jwt_token") }
        set {
            if let v = newValue {
                try? keychain.set(v, key: "jwt_token")
            } else {
                try? keychain.remove("jwt_token")
            }
        }
    }

    var isAuthenticated: Bool { token != nil }

    func setToken(_ token: String) {
        self.token = token
    }

    func clearToken() {
        self.token = nil
    }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try JSONEncoder.racconto.encode(body) }

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200...299:
                break
            case 401:
                self.token = nil
                throw APIError.unauthorized
            case 404:
                throw APIError.notFound
            case 400:
                if let json = try? JSONDecoder.racconto.decode([String: String].self, from: data),
                   let detail = json["detail"],
                   detail.contains("LIMIT_EXCEEDED") {
                    throw APIError.limitExceeded(detail)
                }
                fallthrough
            default:
                throw APIError.serverError(http.statusCode)
            }
        }

        do {
            return try JSONDecoder.racconto.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("=== 디코딩 오류 ===")
            print("타입: \(T.self)")
            print("오류: \(error)")
            if let raw = String(data: data, encoding: .utf8) {
                print("응답 원문: \(raw.prefix(2000))")
            }
            #endif
            throw APIError.decodingError(error)
        }
    }

    // OAuth2 폼 로그인 (application/x-www-form-urlencoded)
    func loginForm(email: String, password: String) async throws -> AuthResponse {
        guard let url = URL(string: baseURL + "/auth/login") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "username=\(email.urlEncoded)&password=\(password.urlEncoded)"
        req.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw APIError.unauthorized
        }
        do {
            return try JSONDecoder.racconto.decode(AuthResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // 응답 없는 요청 (DELETE 등)
    func requestVoid(
        _ path: String,
        method: String,
        body: Encodable? = nil
    ) async throws {
        guard let url = URL(string: baseURL + path) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try JSONEncoder.racconto.encode(body) }

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200...299:
                break
            case 401:
                self.token = nil
                throw APIError.unauthorized
            case 404:
                throw APIError.notFound
            default:
                #if DEBUG
                print("=== requestVoid 오류 ===")
                print("경로: \(method) \(path)")
                print("상태코드: \(http.statusCode)")
                if let raw = String(data: data, encoding: .utf8) { print("응답: \(raw.prefix(500))") }
                #endif
                throw APIError.serverError(http.statusCode)
            }
        }
    }
}

extension JSONDecoder {
    static let racconto: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        // FastAPI가 타임존 없이 마이크로초 ISO8601 반환 (e.g. 2026-05-05T22:36:47.534088)
        // ISO8601DateFormatter는 타임존 필수이므로, 없으면 Z를 붙여 UTC로 처리
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let withoutFraction = ISO8601DateFormatter()
        withoutFraction.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = withFraction.date(from: s) { return date }
            if let date = withoutFraction.date(from: s) { return date }
            // 타임존 없는 경우 Z 추가 후 재시도
            let withZ = s + "Z"
            if let date = withFraction.date(from: withZ) { return date }
            if let date = withoutFraction.date(from: withZ) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "날짜 파싱 실패: \(s)"
            )
        }
        return d
    }()
}

extension JSONEncoder {
    static let racconto: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
