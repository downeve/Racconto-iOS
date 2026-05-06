import Foundation

struct AuthResponse: Codable {
    let accessToken: String
    let tokenType: String
}

struct LoginRequest: Encodable {
    let username: String          // 백엔드가 OAuth2PasswordRequestForm → username 필드 사용
    let password: String
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let name: String?
}

struct MeResponse: Decodable {
    let email: String?
    let username: String?
}
