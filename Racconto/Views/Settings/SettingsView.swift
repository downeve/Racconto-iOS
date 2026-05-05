import SwiftUI

struct UserSettings: Codable {
    var portfolioTheme: String?
    var username: String?
}

struct SettingsUpdateRequest: Encodable {
    var portfolioTheme: String?
}

struct SettingsView: View {
    var authViewModel: AuthViewModel
    @State private var settings: UserSettings?
    @State private var isLoading = false
    @State private var isDark = false

    private let api = RaccontoAPI.shared

    var body: some View {
        List {
            Section("포트폴리오") {
                Toggle("다크 테마", isOn: $isDark)
                    .onChange(of: isDark) { _, newVal in
                        Task { await saveTheme(dark: newVal) }
                    }
            }

            Section {
                Button(role: .destructive) {
                    authViewModel.logout()
                } label: {
                    Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("설정")
        .task { await loadSettings() }
    }

    private func loadSettings() async {
        do {
            settings = try await api.request("/settings/")
            isDark = settings?.portfolioTheme == "dark"
        } catch {}
    }

    private func saveTheme(dark: Bool) async {
        do {
            let req = SettingsUpdateRequest(portfolioTheme: dark ? "dark" : "light")
            settings = try await api.request("/settings/", method: "PUT", body: req)
        } catch {}
    }
}
