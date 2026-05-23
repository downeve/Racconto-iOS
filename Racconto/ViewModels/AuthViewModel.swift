import Foundation
import AuthenticationServices

@MainActor
@Observable
class AuthViewModel: NSObject {
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    var currentUsername: String? = nil
    var oauthProvider: String? = nil
    var tier: String? = nil
    var projectCount: Int = 0
    var projectLimit: Int = 0
    var photoCount: Int = 0
    var photoLimit: Int = 0

    var isSocialUser: Bool { oauthProvider != nil }

    private let api = RaccontoAPI.shared

    override init() {
        super.init()
        isAuthenticated = api.isAuthenticated

        // 401 → API 레이어가 토큰 폐기. UI 동기화를 위해 isAuthenticated를 false로 전환.
        NotificationCenter.default.addObserver(
            forName: .raccontoTokenInvalidated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isAuthenticated = false
                self.currentUsername = nil
                self.oauthProvider = nil
            }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // MainActor 격리 우회 — ASWebAuthenticationSession이 동기 호출
        MainActor.assumeIsolated { resolveAnchor() }
    }

    private func resolveAnchor() -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        if let window = scene?.keyWindow { return window }
        if let scene { return UIWindow(windowScene: scene) }
        preconditionFailure("No UIWindowScene available")
    }

    func fetchMe() async {
        guard isAuthenticated else { return }
        do {
            let me: MeResponse = try await api.request("/auth/me")
            currentUsername = me.username
            oauthProvider = me.oauthProvider
            tier = me.tier
            projectCount = me.projectCount ?? 0
            projectLimit = me.projectLimit ?? 0
            photoCount = me.photoCount ?? 0
            photoLimit = me.photoLimit ?? 0
        } catch let err as APIError {
            // 401은 RaccontoAPI가 .raccontoTokenInvalidated 브로드캐스트로 처리.
            // 그 외 오류만 사용자에게 표시.
            errorMessage = err.errorDescription
        } catch {}
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
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
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Apple Sign In (네이티브)

    func loginWithApple(credential: ASAuthorizationAppleIDCredential) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            errorMessage = "Apple 로그인에 실패했습니다."
            return
        }

        do {
            struct AppleLoginBody: Encodable { let identityToken: String }
            let response: AuthResponse = try await api.request(
                "/auth/apple/ios",
                method: "POST",
                body: AppleLoginBody(identityToken: identityToken)
            )
            api.setToken(response.accessToken)
            isAuthenticated = true
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Google / Naver (ASWebAuthenticationSession)

    func loginWithOAuth(provider: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(RaccontoAPI.baseURL)/auth/\(provider)/login?platform=ios") else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "racconto"
            ) { [weak self] callbackURL, error in
                guard let self else { continuation.resume(); return }

                if let error {
                    // 사용자가 취소한 경우는 에러 메시지 없이 종료
                    if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                        self.errorMessage = "로그인에 실패했습니다."
                    }
                    continuation.resume()
                    return
                }

                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
                    self.errorMessage = "로그인에 실패했습니다."
                    continuation.resume()
                    return
                }

                self.api.setToken(token)
                self.isAuthenticated = true
                continuation.resume()
            }
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self
            session.start()
        }
    }

    func logout() {
        api.clearToken()
        isAuthenticated = false
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthViewModel: ASWebAuthenticationPresentationContextProviding {}

// 응답 본문이 없거나 무시해도 되는 경우
struct EmptyResponse: Decodable {}
