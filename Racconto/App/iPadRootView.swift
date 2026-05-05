import SwiftUI

struct iPadRootView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var listVM = ProjectListViewModel()
    @State private var selectedProject: Project? = nil

    var body: some View {
        NavigationSplitView {
            ProjectListView(viewModel: listVM, selectedProject: $selectedProject)
                .navigationTitle("Racconto")
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        HStack {
                            Spacer()
                            Button(role: .destructive) {
                                authViewModel.logout()
                            } label: {
                                Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                    }
                }
        } detail: {
            if let project = selectedProject {
                ProjectDetailView(project: project)
            } else {
                ContentUnavailableView("프로젝트를 선택하세요", systemImage: "rectangle.stack")
            }
        }
    }
}
