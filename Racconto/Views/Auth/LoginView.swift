import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false

    var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)

                    Text("Racconto")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .tracking(2)

                    // 이메일/비밀번호 로그인
                    VStack(spacing: 16) {
                        TextField("이메일", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(Radius.large)

                        SecureField("비밀번호", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(Radius.large)
                    }

                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await authViewModel.login(email: email, password: password) }
                    } label: {
                        if authViewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("로그인")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(Color.primary)
                    .foregroundStyle(Color(UIColor.systemBackground))
                    .cornerRadius(Radius.large)
                    .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)

                    Button("계정이 없으신가요? 회원가입") {
                        showRegister = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    // 구분선
                    HStack {
                        Rectangle().fill(Color(.separator)).frame(height: 1)
                        Text("또는")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                        Rectangle().fill(Color(.separator)).frame(height: 1)
                    }

                    // 소셜 로그인
                    VStack(spacing: 12) {
                        // Apple
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.email]
                        } onCompletion: { result in
                            switch result {
                            case .success(let auth):
                                guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
                                Task { await authViewModel.loginWithApple(credential: credential) }
                            case .failure:
                                break
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .cornerRadius(Radius.large)

                        // Google
                        Button {
                            Task { await authViewModel.loginWithOAuth(provider: "google") }
                        } label: {
                            HStack(spacing: 10) {
                                GoogleLogoMark()
                                    .frame(width: 20, height: 20)
                                Text("Google로 로그인")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.large)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                            .cornerRadius(Radius.large)
                        }
                        .disabled(authViewModel.isLoading)

                        // 네이버
                        Button {
                            Task { await authViewModel.loginWithOAuth(provider: "naver") }
                        } label: {
                            HStack(spacing: 10) {
                                NaverLogoMark()
                                    .frame(width: 20, height: 20)
                                Text("네이버로 로그인")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(red: 0.01, green: 0.78, blue: 0.35))
                            .cornerRadius(Radius.large)
                        }
                        .disabled(authViewModel.isLoading)

                        // LINE
                        Button {
                            Task { await authViewModel.loginWithOAuth(provider: "line") }
                        } label: {
                            HStack(spacing: 10) {
                                LineLogoMark()
                                    .frame(width: 20, height: 20)
                                Text("LINE으로 로그인")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(red: 0.024, green: 0.780, blue: 0.333))
                            .cornerRadius(Radius.large)
                        }
                        .disabled(authViewModel.isLoading)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 32)
            }
            .sheet(isPresented: $showRegister) {
                RegisterView(authViewModel: authViewModel)
            }
        }
    }
}

// MARK: - Google 로고 (SVG 경로 재현)

private struct GoogleLogoMark: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            // Blue
            var p = Path(); p.move(to: CGPoint(x: s, y: s * 0.52))
            p.addLine(to: CGPoint(x: s, y: s * 0.52))
            ctx.fill(googlePath(size: s, part: 0), with: .color(Color(red: 0.259, green: 0.522, blue: 0.957)))
            ctx.fill(googlePath(size: s, part: 1), with: .color(Color(red: 0.204, green: 0.659, blue: 0.325)))
            ctx.fill(googlePath(size: s, part: 2), with: .color(Color(red: 0.984, green: 0.737, blue: 0.020)))
            ctx.fill(googlePath(size: s, part: 3), with: .color(Color(red: 0.918, green: 0.263, blue: 0.208)))
        }
    }

    private func googlePath(size s: CGFloat, part: Int) -> Path {
        var p = Path()
        switch part {
        case 0: // Blue (right)
            p.move(to: CGPoint(x: s, y: s * 0.52))
            p.addLine(to: CGPoint(x: s * 0.51, y: s * 0.52))
            p.addLine(to: CGPoint(x: s * 0.51, y: s * 0.70))
            p.addLine(to: CGPoint(x: s * 0.755, y: s * 0.70))
            p.addCurve(to: CGPoint(x: s * 0.51, y: s * 0.955),
                       control1: CGPoint(x: s * 0.740, y: s * 0.826),
                       control2: CGPoint(x: s * 0.638, y: s * 0.955))
            p.addLine(to: CGPoint(x: s * 0.51, y: s))
            p.addCurve(to: CGPoint(x: s, y: s * 0.52),
                       control1: CGPoint(x: s * 0.772, y: s),
                       control2: CGPoint(x: s, y: s * 0.793))
        case 1: // Green (bottom)
            p.move(to: CGPoint(x: s * 0.51, y: s))
            p.addCurve(to: CGPoint(x: s * 0.092, y: s * 0.795),
                       control1: CGPoint(x: s * 0.292, y: s),
                       control2: CGPoint(x: s * 0.166, y: s * 0.912))
            p.addLine(to: CGPoint(x: s * 0.397, y: s * 0.561))
            p.addCurve(to: CGPoint(x: s * 0.51, y: s * 0.955),
                       control1: CGPoint(x: s * 0.452, y: s * 0.756),
                       control2: CGPoint(x: s * 0.481, y: s * 0.858))
        case 2: // Yellow (bottom left)
            p.move(to: CGPoint(x: s * 0.092, y: s * 0.795))
            p.addCurve(to: CGPoint(x: s * 0.045, y: s * 0.5),
                       control1: CGPoint(x: s * 0.060, y: s * 0.712),
                       control2: CGPoint(x: s * 0.045, y: s * 0.608))
            p.addCurve(to: CGPoint(x: s * 0.092, y: s * 0.205),
                       control1: CGPoint(x: s * 0.045, y: s * 0.392),
                       control2: CGPoint(x: s * 0.060, y: s * 0.287))
            p.addLine(to: CGPoint(x: s * 0.397, y: s * 0.439))
            p.addCurve(to: CGPoint(x: s * 0.397, y: s * 0.561),
                       control1: CGPoint(x: s * 0.377, y: s * 0.476),
                       control2: CGPoint(x: s * 0.377, y: s * 0.524))
        case 3: // Red (top)
            p.move(to: CGPoint(x: s * 0.51, y: s * 0.045))
            p.addCurve(to: CGPoint(x: s * 0.092, y: s * 0.205),
                       control1: CGPoint(x: s * 0.292, y: s * 0.045),
                       control2: CGPoint(x: s * 0.166, y: s * 0.108))
            p.addLine(to: CGPoint(x: s * 0.397, y: s * 0.439))
            p.addCurve(to: CGPoint(x: s * 0.51, y: s * 0.23),
                       control1: CGPoint(x: s * 0.452, y: s * 0.38),
                       control2: CGPoint(x: s * 0.479, y: s * 0.295))
            p.addCurve(to: CGPoint(x: s * 0.72, y: s * 0.31),
                       control1: CGPoint(x: s * 0.574, y: s * 0.23),
                       control2: CGPoint(x: s * 0.655, y: s * 0.26))
            p.addLine(to: CGPoint(x: s * 0.86, y: s * 0.17))
            p.addCurve(to: CGPoint(x: s * 0.51, y: s * 0.045),
                       control1: CGPoint(x: s * 0.786, y: s * 0.100),
                       control2: CGPoint(x: s * 0.654, y: s * 0.045))
        default: break
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - LINE 로고 (말풍선)

private struct LineLogoMark: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            // 말풍선 본체 (둥근 사각형)
            let bubbleRect = CGRect(x: s * 0.05, y: s * 0.05, width: s * 0.90, height: s * 0.75)
            let bubble = Path(roundedRect: bubbleRect, cornerRadius: s * 0.18)
            ctx.fill(bubble, with: .color(.white))
            // 꼬리 (좌하단 삼각형)
            var tail = Path()
            tail.move(to: CGPoint(x: s * 0.15, y: s * 0.80))
            tail.addLine(to: CGPoint(x: s * 0.05, y: s * 0.95))
            tail.addLine(to: CGPoint(x: s * 0.38, y: s * 0.80))
            tail.closeSubpath()
            ctx.fill(tail, with: .color(.white))
            // 내부 횡선 3개
            let lineColor = GraphicsContext.Shading.color(Color(red: 0.024, green: 0.780, blue: 0.333))
            for i in 0..<3 {
                let y = s * (0.26 + Double(i) * 0.165)
                var line = Path()
                line.move(to: CGPoint(x: s * 0.25, y: y))
                line.addLine(to: CGPoint(x: s * 0.75, y: y))
                ctx.stroke(line, with: lineColor, lineWidth: s * 0.09)
            }
        }
    }
}

// MARK: - 네이버 로고 (N 마크)

private struct NaverLogoMark: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            var p = Path()
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: 0, y: s))
            p.addLine(to: CGPoint(x: s * 0.32, y: s))
            p.addLine(to: CGPoint(x: s * 0.32, y: s * 0.535))
            p.addLine(to: CGPoint(x: s * 0.68, y: s))
            p.addLine(to: CGPoint(x: s, y: s))
            p.addLine(to: CGPoint(x: s, y: 0))
            p.addLine(to: CGPoint(x: s * 0.68, y: 0))
            p.addLine(to: CGPoint(x: s * 0.68, y: s * 0.465))
            p.addLine(to: CGPoint(x: s * 0.32, y: 0))
            p.closeSubpath()
            ctx.fill(p, with: .color(.white))
        }
    }
}
