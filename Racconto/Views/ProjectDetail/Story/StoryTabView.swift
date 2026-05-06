import SwiftUI

struct StoryTabView: View {
    let project: Project
    var viewModel: StoryViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showPreview = false
    @State private var showSidebar = true
    @State private var scrollToChapterId: String? = nil

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                mainContent
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

    // MARK: - iPad 레이아웃

    private var iPadLayout: some View {
        HStack(spacing: 0) {
            if showSidebar {
                chapterSidebar
                Divider()
            }
            mainContent
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showSidebar.toggle() }
                } label: {
                    Image(systemName: "sidebar.left")
                        .symbolVariant(showSidebar ? .fill : .none)
                }
            }
        }
    }

    // MARK: - 챕터 사이드바 (iPad 전용)

    private var chapterSidebar: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if viewModel.chapterTree.isEmpty {
                    Text("챕터 없음")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                } else {
                    ForEach(Array(viewModel.chapterTree.enumerated()), id: \.element.parent.id) { idx, node in
                        // 최상위 챕터
                        Button {
                            scrollToChapterId = node.parent.id
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("챕터 \(idx + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(node.parent.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        // 서브챕터
                        ForEach(Array(node.subs.enumerated()), id: \.element.id) { subIdx, sub in
                            Button {
                                scrollToChapterId = sub.id
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("챕터 \(idx + 1).\(subIdx + 1)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(sub.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.leading, 28)
                                .padding(.trailing, 16)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }

                        Divider().padding(.horizontal, 12)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .frame(width: 220)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - 메인 콘텐츠 (공통)

    private var mainContent: some View {
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
                StoryEditorView(viewModel: viewModel, project: project, scrollToChapterId: $scrollToChapterId)
            }
        }
    }
}
