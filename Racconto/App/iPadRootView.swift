import SwiftUI

struct iPadRootView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var listVM = ProjectListViewModel()
    @State private var selectedProject: Project? = nil
    @State private var selectedSidebar: SidebarItem? = .projects

    enum SidebarItem: Hashable {
        case projects
        case portfolio
        case trash
        case settings
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebar) {
                Section("라이브러리") {
                    Label("프로젝트", systemImage: "rectangle.stack")
                        .tag(SidebarItem.projects)
                    Label("포트폴리오", systemImage: "person.crop.rectangle.stack")
                        .tag(SidebarItem.portfolio)
                    Label("휴지통", systemImage: "trash")
                        .tag(SidebarItem.trash)
                }
                Section {
                    Label("설정", systemImage: "gearshape")
                        .tag(SidebarItem.settings)
                }
            }
            .navigationTitle("Racconto")
        } content: {
            switch selectedSidebar {
            case .projects:
                ProjectListView(viewModel: listVM, selectedProject: $selectedProject)
                    .navigationTitle("프로젝트")
            case .portfolio:
                PublicPortfolioView()
            case .trash:
                TrashView()
            case .settings:
                SettingsView(authViewModel: authViewModel)
            case nil:
                ContentUnavailableView("항목을 선택하세요", systemImage: "sidebar.left")
            }
        } detail: {
            if selectedSidebar == .projects {
                if let project = selectedProject {
                    ProjectDetailView(project: project)
                        .id(project.id)
                } else {
                    ContentUnavailableView("프로젝트를 선택하세요", systemImage: "rectangle.stack")
                }
            } else {
                ContentUnavailableView("항목을 선택하세요", systemImage: "sidebar.left")
            }
        }
    }
}
