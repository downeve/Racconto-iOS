import SwiftUI

struct UserSettings: Codable {
    var portfolioTheme: String?
    var username: String?
    var colorLabelRed: String?
    var colorLabelOrange: String?
    var colorLabelYellow: String?
    var colorLabelGreen: String?
    var colorLabelBlue: String?
}

struct SettingsUpdateRequest: Encodable {
    var portfolioTheme: String?
}

struct ColorLabelsUpdateRequest: Encodable {
    var colorLabelRed: String
    var colorLabelOrange: String
    var colorLabelYellow: String
    var colorLabelGreen: String
    var colorLabelBlue: String
}

struct UsernameUpdateRequest: Encodable {
    let username: String
}

struct PasswordUpdateRequest: Encodable {
    let currentPassword: String
    let newPassword: String
}

struct SettingsView: View {
    var authViewModel: AuthViewModel
    @State private var settings: UserSettings?
    @State private var isDark = false

    // 컬러 레이블
    @State private var labelRed = ""
    @State private var labelOrange = ""
    @State private var labelYellow = ""
    @State private var labelGreen = ""
    @State private var labelBlue = ""
    @State private var labelsSaved = false

    // 유저네임
    @State private var usernameInput = ""
    @State private var usernameError: String? = nil
    @State private var usernameSaved = false

    // 비밀번호
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordError: String? = nil
    @State private var passwordSuccess = false

    private let api = RaccontoAPI.shared

    private let colorRows: [(key: String, label: String, color: Color)] = [
        ("red",    "빨강", .red),
        ("orange", "주황", .orange),
        ("yellow", "노랑", .yellow),
        ("green",  "초록", .green),
        ("blue",   "파랑", .blue),
    ]

    var body: some View {
        List {
            // MARK: 유저네임
            Section {
                HStack(spacing: 2) {
                    Text("racconto.app/")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("username", text: $usernameInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.subheadline)
                }
                if let err = usernameError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                if usernameSaved {
                    Text("저장됐습니다").font(.caption).foregroundStyle(.green)
                }
                Button("유저네임 저장") {
                    Task { await saveUsername() }
                }
                .disabled(usernameInput.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                Text("유저네임")
            }

            // MARK: 포트폴리오 테마
            Section("포트폴리오") {
                Toggle("다크 테마", isOn: $isDark)
                    .onChange(of: isDark) { _, newVal in
                        Task { await saveTheme(dark: newVal) }
                    }
            }

            // MARK: 컬러 레이블
            Section {
                ForEach(colorRows, id: \.key) { row in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(row.color)
                            .frame(width: 12, height: 12)
                        Text(row.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .leading)
                        TextField("기본 이름", text: labelBinding(for: row.key))
                            .font(.subheadline)
                    }
                }
                if labelsSaved {
                    Text("저장됐습니다").font(.caption).foregroundStyle(.green)
                }
                Button("레이블 이름 저장") {
                    Task { await saveColorLabels() }
                }
            } header: {
                Text("컬러 레이블")
            }

            // MARK: 비밀번호 변경
            Section {
                SecureField("현재 비밀번호", text: $currentPassword)
                SecureField("새 비밀번호 (8자 이상)", text: $newPassword)
                SecureField("새 비밀번호 확인", text: $confirmPassword)
                if let err = passwordError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                if passwordSuccess {
                    Text("비밀번호가 변경됐습니다").font(.caption).foregroundStyle(.green)
                }
                Button("비밀번호 변경") {
                    Task { await changePassword() }
                }
                .disabled(currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
            } header: {
                Text("비밀번호 변경")
            }

            // MARK: 계정
            Section {
                Button(role: .destructive) {
                    authViewModel.logout()
                } label: {
                    Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("설정")
        .task {
            await loadSettings()
            await authViewModel.fetchMe()
            if usernameInput.isEmpty {
                usernameInput = authViewModel.currentUsername ?? ""
            }
        }
    }

    // MARK: - Helpers

    private func labelBinding(for key: String) -> Binding<String> {
        switch key {
        case "red":    return $labelRed
        case "orange": return $labelOrange
        case "yellow": return $labelYellow
        case "green":  return $labelGreen
        default:       return $labelBlue
        }
    }

    // MARK: - API

    private func loadSettings() async {
        do {
            settings = try await api.request("/settings/")
            isDark          = settings?.portfolioTheme == "dark"
            labelRed    = settings?.colorLabelRed    ?? ""
            labelOrange = settings?.colorLabelOrange ?? ""
            labelYellow = settings?.colorLabelYellow ?? ""
            labelGreen  = settings?.colorLabelGreen  ?? ""
            labelBlue   = settings?.colorLabelBlue   ?? ""
        } catch {}
    }

    private func saveTheme(dark: Bool) async {
        do {
            let req = SettingsUpdateRequest(portfolioTheme: dark ? "dark" : "light")
            settings = try await api.request("/settings/", method: "PUT", body: req)
        } catch {}
    }

    private func saveColorLabels() async {
        do {
            let req = ColorLabelsUpdateRequest(
                colorLabelRed:    labelRed,
                colorLabelOrange: labelOrange,
                colorLabelYellow: labelYellow,
                colorLabelGreen:  labelGreen,
                colorLabelBlue:   labelBlue
            )
            try await api.requestVoid("/settings/batch/update", method: "PUT", body: req)
            labelsSaved = true
            try? await Task.sleep(for: .seconds(2))
            labelsSaved = false
        } catch {}
    }

    private func saveUsername() async {
        usernameError = nil
        usernameSaved = false
        let trimmed = usernameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try await api.requestVoid("/auth/username", method: "PUT",
                body: UsernameUpdateRequest(username: trimmed))
            authViewModel.currentUsername = trimmed
            usernameSaved = true
            try? await Task.sleep(for: .seconds(2))
            usernameSaved = false
        } catch let err as APIError {
            usernameError = err.errorDescription
        } catch {}
    }

    private func changePassword() async {
        passwordError = nil
        passwordSuccess = false
        guard newPassword == confirmPassword else {
            passwordError = "새 비밀번호가 일치하지 않습니다"
            return
        }
        guard newPassword.count >= 8 else {
            passwordError = "비밀번호는 8자 이상이어야 합니다"
            return
        }
        do {
            try await api.requestVoid("/auth/password", method: "PUT",
                body: PasswordUpdateRequest(currentPassword: currentPassword, newPassword: newPassword))
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            passwordSuccess = true
            try? await Task.sleep(for: .seconds(2))
            passwordSuccess = false
        } catch let err as APIError {
            passwordError = err.errorDescription
        } catch {}
    }
}
