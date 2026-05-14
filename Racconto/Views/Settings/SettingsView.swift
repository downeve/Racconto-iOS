import SwiftUI

struct UserSettings: Codable {
    var portfolioTheme: String?
    var username: String?
    var colorLabelRed: String?
    var colorLabelPurple: String?
    var colorLabelYellow: String?
    var colorLabelGreen: String?
    var colorLabelBlue: String?
}

struct SettingsUpdateRequest: Encodable {
    var portfolioTheme: String?
}

struct ColorLabelsUpdateRequest: Encodable {
    var colorLabelRed: String
    var colorLabelPurple: String
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

struct WithdrawRequest: Encodable {
    let password: String?
    let lang: String
}

enum UsernameStatus { case idle, checking, available, taken, invalid }

struct SettingsView: View {
    var authViewModel: AuthViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var settings: UserSettings?
    @State private var isDark = false

    // 컬러 레이블
    @State private var labelRed = ""
    @State private var labelPurple = ""
    @State private var labelYellow = ""
    @State private var labelGreen = ""
    @State private var labelBlue = ""
    @State private var labelsSaved = false

    // 유저네임
    @State private var usernameInput = ""
    @State private var usernameStatus: UsernameStatus = .idle
    @State private var usernameSaved = false
    @State private var usernameCheckTask: Task<Void, Never>? = nil

    // 비밀번호
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordError: String? = nil
    @State private var passwordSuccess = false

    // 회원 탈퇴
    @State private var showWithdrawConfirm = false
    @State private var withdrawPassword = ""
    @State private var withdrawError: String? = nil

    private let api = RaccontoAPI.shared

    private let colorRows: [(key: String, label: String, color: Color)] = [
        ("red",    "빨강", .red),
        ("yellow", "노랑", .yellow),
        ("green",  "초록", .green),
        ("blue",   "파랑", .blue),
        ("purple", "보라", .purple),
    ]

    var body: some View {
        List {
            // MARK: 유저네임
            Section {
                HStack(spacing: 6) {
                    Text("racconto.app/")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("username", text: $usernameInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.subheadline)
                        .onChange(of: usernameInput) { _, newValue in
                            scheduleUsernameCheck(newValue)
                        }
                    Group {
                        switch usernameStatus {
                        case .checking:
                            ProgressView().scaleEffect(0.7)
                        case .available:
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        case .taken, .invalid:
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                        case .idle:
                            EmptyView()
                        }
                    }
                    .font(.subheadline)
                }
                if usernameStatus == .invalid {
                    Text("영문, 숫자, -, _ 만 사용 가능 (3자 이상)").font(.caption).foregroundStyle(.red)
                } else if usernameStatus == .taken {
                    Text("이미 사용 중인 유저네임입니다").font(.caption).foregroundStyle(.red)
                } else if usernameSaved {
                    Text("저장됐습니다").font(.caption).foregroundStyle(.green)
                }
                Button("유저네임 저장") {
                    Task { await saveUsername() }
                }
                .disabled(
                    usernameInput.trimmingCharacters(in: .whitespaces).isEmpty ||
                    usernameStatus == .checking ||
                    usernameStatus == .taken ||
                    usernameStatus == .invalid
                )
            } header: {
                Text("유저네임")
            }

            // MARK: 사용량
            Section {
                HStack {
                    Text("프로젝트")
                    Spacer()
                    Text("\(authViewModel.projectCount) / \(authViewModel.projectLimit)")
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: Double(authViewModel.projectCount), total: Double(max(authViewModel.projectLimit, 1)))
                    .tint(authViewModel.projectCount >= authViewModel.projectLimit ? .red : .blue)
                HStack {
                    Text("사진")
                    Spacer()
                    Text("\(authViewModel.photoCount) / \(authViewModel.photoLimit)")
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: Double(authViewModel.photoCount), total: Double(max(authViewModel.photoLimit, 1)))
                    .tint(authViewModel.photoCount >= authViewModel.photoLimit ? .red : .blue)
                if let tier = authViewModel.tier {
                    HStack {
                        Text("플랜")
                        Spacer()
                        Text(tier).foregroundStyle(.secondary).textCase(.uppercase)
                    }
                }
            } header: {
                Text("사용량")
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
                if horizontalSizeClass == .regular {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(colorRows, id: \.key) { row in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(row.color)
                                    .frame(width: 12, height: 12)
                                Text(row.label)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, alignment: .leading)
                                TextField("기본 이름", text: labelBinding(for: row.key))
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(colorRows, id: \.key) { row in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(row.color)
                                .frame(width: 12, height: 12)
                            Text(row.label)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            TextField("기본 이름", text: labelBinding(for: row.key))
                                .font(.subheadline)
                        }
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
            if !authViewModel.isSocialUser {
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
            }

            // MARK: 계정
            Section {
                Button(role: .destructive) {
                    authViewModel.logout()
                } label: {
                    Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                }
                Button(role: .destructive) {
                    withdrawPassword = ""
                    withdrawError = nil
                    showWithdrawConfirm = true
                } label: {
                    Label("회원 탈퇴", systemImage: "person.crop.circle.badge.minus")
                }
            }
        }
        .navigationTitle("설정")
        .alert("회원 탈퇴", isPresented: $showWithdrawConfirm) {
            if !authViewModel.isSocialUser {
                SecureField("비밀번호", text: $withdrawPassword)
            }
            Button("탈퇴", role: .destructive) {
                Task { await withdraw() }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("탈퇴하면 모든 데이터가 삭제되며 복구할 수 없습니다.")
        }
        .alert("탈퇴 실패", isPresented: Binding(
            get: { withdrawError != nil },
            set: { if !$0 { withdrawError = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(withdrawError ?? "")
        }
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
        case "purple": return $labelPurple
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
            labelPurple = settings?.colorLabelPurple ?? ""
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
                colorLabelPurple: labelPurple,
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

    private func scheduleUsernameCheck(_ value: String) {
        usernameCheckTask?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { usernameStatus = .idle; return }
        guard trimmed.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil else {
            usernameStatus = .invalid; return
        }
        if trimmed == authViewModel.currentUsername { usernameStatus = .idle; return }
        usernameStatus = .checking
        usernameCheckTask = Task {
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            await checkUsername(trimmed)
        }
    }

    private func checkUsername(_ value: String) async {
        struct CheckResponse: Decodable { let available: Bool }
        do {
            let res: CheckResponse = try await api.request("/auth/check-username/\(value)")
            usernameStatus = res.available ? .available : .taken
        } catch {
            usernameStatus = .idle
        }
    }

    private func saveUsername() async {
        usernameSaved = false
        let trimmed = usernameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try await api.requestVoid("/auth/username", method: "PUT",
                body: UsernameUpdateRequest(username: trimmed))
            authViewModel.currentUsername = trimmed
            usernameStatus = .idle
            usernameSaved = true
            try? await Task.sleep(for: .seconds(2))
            usernameSaved = false
        } catch let err as APIError {
            usernameStatus = .taken
            _ = err
        } catch {}
    }

    private func withdraw() async {
        withdrawError = nil
        let lang = Locale.current.language.languageCode?.identifier == "ko" ? "ko" : "en"
        let password: String? = authViewModel.isSocialUser ? nil : withdrawPassword
        do {
            try await api.requestVoid("/auth/withdraw", method: "DELETE",
                body: WithdrawRequest(password: password, lang: lang))
            authViewModel.logout()
        } catch let err as APIError {
            withdrawError = err.errorDescription
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
            authViewModel.logout()
        } catch let err as APIError {
            passwordError = err.errorDescription
        } catch {}
    }
}
