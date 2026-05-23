import SwiftUI

struct PadRootView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var listVM = ProjectListViewModel()
    @State private var selectedProject: Project? = nil
    @State private var selectedTab: TabItem = .projects

    enum TabItem: Hashable {
        case projects, portfolio, trash, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            projectsTab
                .tabItem { Label("프로젝트", systemImage: "rectangle.stack") }
                .tag(TabItem.projects)

            NavigationStack { PublicPortfolioView() }
                .tabItem { Label("포트폴리오", systemImage: "person.crop.rectangle.stack") }
                .tag(TabItem.portfolio)

            NavigationStack { TrashView() }
                .tabItem { Label("휴지통", systemImage: "trash") }
                .tag(TabItem.trash)

            NavigationStack { SettingsView(authViewModel: authViewModel) }
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(TabItem.settings)
        }
    }

    private var projectsTab: some View {
        NavigationSplitView {
            ProjectListView(viewModel: listVM, selectedProject: $selectedProject)
        } detail: {
            if let project = selectedProject {
                ProjectDetailView(project: project)
                    .id(project.id)
            } else {
                ContentUnavailableView("프로젝트를 선택하세요", systemImage: "rectangle.stack")
            }
        }
    }
}
