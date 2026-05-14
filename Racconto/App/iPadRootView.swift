import SwiftUI

struct iPadRootView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var listVM = ProjectListViewModel()
    @State private var selectedProject: Project? = nil
    @State private var selectedTab: TabItem = .projects
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

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
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ProjectListView(viewModel: listVM, selectedProject: $selectedProject, onDismissSidebar: {
                withAnimation { columnVisibility = .detailOnly }
            })
        } detail: {
            if let project = selectedProject {
                ProjectDetailView(project: project)
                    .id(project.id)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            if columnVisibility == .detailOnly {
                                Button {
                                    withAnimation { columnVisibility = .all }
                                } label: {
                                    Image(systemName: "sidebar.left")
                                }
                            }
                        }
                    }
            } else {
                ContentUnavailableView("프로젝트를 선택하세요", systemImage: "rectangle.stack")
            }
        }
    }
}
