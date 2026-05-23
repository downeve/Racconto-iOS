import SwiftUI

struct PhoneRootView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var listVM = ProjectListViewModel()

    var body: some View {
        TabView {
            Tab("프로젝트", systemImage: "rectangle.stack") {
                NavigationStack {
                    ProjectListView(viewModel: listVM, selectedProject: nil)
                }
            }
            Tab("포트폴리오", systemImage: "person.crop.rectangle.stack") {
                NavigationStack {
                    PublicPortfolioView()
                }
            }
            Tab("휴지통", systemImage: "trash") {
                NavigationStack {
                    TrashView()
                }
            }
            Tab("설정", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView(authViewModel: authViewModel)
                }
            }
        }
    }
}
