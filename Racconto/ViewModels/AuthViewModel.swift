import Foundation

@Observable
class AuthViewModel {
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    private let api = RaccontoAPI.shared

    init() {
        isAuthenticated = api.isAuthenticated
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // OAuth2PasswordRequestForm → application/x-www-form-urlencoded
            let response: AuthResponse = try await api.loginForm(email: email, password: password)
            api.setToken(response.accessToken)
            isAuthenticated = true
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func register(email: String, password: String, name: String?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let body = RegisterRequest(email: email, password: password, name: name)
            let _: EmptyResponse = try await api.request("/auth/register", method: "POST", body: body)
            // 이메일 인증 안내 — 성공 처리는 뷰에서
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        api.clearToken()
        isAuthenticated = false
    }
}

// 응답 본문이 없거나 무시해도 되는 경우
struct EmptyResponse: Decodable {}
