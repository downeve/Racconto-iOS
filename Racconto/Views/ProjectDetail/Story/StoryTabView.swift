import SwiftUI

struct StoryTabView: View {
    let project: Project
    var viewModel: StoryViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showOutline = false

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .task { if viewModel.chapters.isEmpty { await viewModel.load(projectId: project.id) } }
        .alert("오류", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("확인") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - iPhone

    private var iPhoneLayout: some View {
        ChapterDetailView(viewModel: viewModel, project: project)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showOutline = true } label: {
                        Image(systemName: "sidebar.left")
                    }
                }
            }
            .sheet(isPresented: $showOutline) {
                ChapterOutlineSheet(viewModel: viewModel, project: project)
            }
    }

    // MARK: - iPad

    private var iPadLayout: some View {
        NavigationSplitView {
            ChapterOutlineSheet(viewModel: viewModel, project: project, showDismissButton: false)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            ChapterDetailView(viewModel: viewModel, project: project)
        }
    }
}
