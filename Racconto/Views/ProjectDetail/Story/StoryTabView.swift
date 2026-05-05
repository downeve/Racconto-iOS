import SwiftUI

struct StoryTabView: View {
    let project: Project
    var viewModel: StoryViewModel
    @State private var showPreview = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(showPreview ? "편집" : "미리보기") {
                    showPreview.toggle()
                }
                .font(.subheadline)
                .padding(.trailing, 16)
                .padding(.vertical, 8)
            }
            Divider()

            if viewModel.isLoading && viewModel.chapters.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if showPreview {
                StoryPreviewView(viewModel: viewModel, projectId: project.id)
            } else {
                StoryEditorView(viewModel: viewModel, project: project)
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
}
