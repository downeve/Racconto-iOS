import SwiftUI

struct StoryTabView: View {
    let project: Project
    var viewModel: StoryViewModel
    @State private var showOutline = false
    @State private var showPreview = false
    @State private var showInsert = false   // Phase 2

    var body: some View {
        content
            .task { if viewModel.chapters.isEmpty { await viewModel.load(projectId: project.id) } }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showOutline = true } label: {
                        Image(systemName: "list.bullet")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(showPreview ? "편집" : "미리보기") { showPreview.toggle() }
                }
            }
            .sheet(isPresented: $showOutline) {
                ChapterOutlineSheet(viewModel: viewModel)
            }
            .alert("오류", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("확인") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }

    private var content: some View {
        ZStack(alignment: .bottomTrailing) {
            if viewModel.isLoading && viewModel.chapters.isEmpty {
                ProgressView()
            } else if viewModel.chapterTree.isEmpty {
                ContentUnavailableView(
                    "챕터가 없습니다",
                    systemImage: "text.book.closed",
                    description: Text("우하단 + 버튼으로 첫 챕터를 추가하세요")
                )
            } else if showPreview {
                StoryPreviewView(viewModel: viewModel, projectId: project.id)
            } else {
                ChapterStackView(viewModel: viewModel, project: project)
            }

            if !showPreview { fab }
        }
    }

    private var fab: some View {
        Button {
            showInsert = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .medium))
                .frame(width: 56, height: 56)
                .background(Color.primary)
                .foregroundStyle(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        }
        .padding(.trailing, 18)
        .padding(.bottom, 24)
    }
}
