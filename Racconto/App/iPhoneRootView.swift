import SwiftUI

struct iPhoneRootView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var listVM = ProjectListViewModel()

    var body: some View {
        TabView {
            Tab("프로젝트", systemImage: "rectangle.stack") {
                NavigationStack {
                    ProjectListView(viewModel: listVM, selectedProject: nil)
                }
            }
            Tab("설정", systemImage: "gearshape") {
                NavigationStack {
                    SettingsStubView(authViewModel: authViewModel)
                        .navigationTitle("설정")
                }
            }
        }
    }
}

struct SettingsStubView: View {
    var authViewModel: AuthViewModel

    var body: some View {
        List {
            Button("로그아웃", role: .destructive) {
                authViewModel.logout()
            }
        }
    }
}
