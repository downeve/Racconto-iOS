import SwiftUI

struct StoryEditorView: View {
    var viewModel: StoryViewModel
    let project: Project
    @State private var showAddChapter = false
    @State private var newChapterTitle = ""
    @State private var showChapterPicker = false   // for "텍스트 추가"

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if viewModel.chapterTree.isEmpty {
                        ContentUnavailableView("챕터가 없습니다", systemImage: "text.book.closed")
                            .padding(.top, 60)
                    } else {
                        ForEach(viewModel.chapterTree, id: \.parent.id) { node in
                            ChapterSectionView(node: node, viewModel: viewModel, project: project)
                        }
                    }
                }
                .padding(.bottom, 100)
            }

            // FAB: 챕터 추가
            Button {
                newChapterTitle = ""
                showAddChapter = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.medium)
                    .frame(width: 52, height: 52)
                    .background(Color.primary)
                    .foregroundStyle(Color(UIColor.systemBackground))
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showChapterPicker = true
                } label: {
                    Label("텍스트 추가", systemImage: "text.badge.plus")
                }
            }
        }
        .alert("새 챕터", isPresented: $showAddChapter) {
            TextField("챕터 제목", text: $newChapterTitle)
            Button("생성") {
                let title = newChapterTitle.trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    Task { await viewModel.createChapter(title: title) }
                }
            }
            Button("취소", role: .cancel) {}
        }
        .sheet(isPresented: $showChapterPicker) {
            ChapterPickerSheet(projectId: project.id) { chapter in
                Task { await viewModel.addTextItem(chapterId: chapter.id, content: "") }
            }
        }
    }
}

struct ChapterSectionView: View {
    let node: ChapterNode
    var viewModel: StoryViewModel
    let project: Project
    @State private var editingTitle = false
    @State private var newTitle = ""
    @State private var showAddSub = false
    @State private var subTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 최상위 챕터 헤더
            chapterHeader(chapter: node.parent, isTop: true)

            // 최상위 챕터 블록
            blockList(for: node.parent)

            // 서브챕터
            ForEach(node.subs) { sub in
                VStack(alignment: .leading, spacing: 0) {
                    chapterHeader(chapter: sub, isTop: false)
                    blockList(for: sub)
                }
                .padding(.leading, 16)
            }
        }
        .padding(.bottom, 8)
        .alert("챕터 제목 수정", isPresented: $editingTitle) {
            TextField("제목", text: $newTitle)
            Button("저장") {
                Task { await viewModel.updateChapter(id: node.parent.id, title: newTitle) }
            }
            Button("취소", role: .cancel) {}
        }
        .alert("서브챕터 추가", isPresented: $showAddSub) {
            TextField("챕터 제목", text: $subTitle)
            Button("생성") {
                let title = subTitle.trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    Task { await viewModel.createChapter(title: title, parentId: node.parent.id) }
                }
            }
            Button("취소", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func chapterHeader(chapter: Chapter, isTop: Bool) -> some View {
        HStack(spacing: 8) {
            Text(chapter.title)
                .font(isTop ? .headline : .subheadline)
                .fontWeight(isTop ? .semibold : .medium)
                .foregroundStyle(isTop ? .primary : .secondary)

            Spacer()

            HStack(spacing: 4) {
                Button {
                    Task { await viewModel.moveChapterUp(chapter) }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                Button {
                    Task { await viewModel.moveChapterDown(chapter) }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)

            Menu {
                Button {
                    newTitle = chapter.title
                    editingTitle = true
                } label: {
                    Label("이름 수정", systemImage: "pencil")
                }
                if isTop {
                    Button {
                        subTitle = ""
                        showAddSub = true
                    } label: {
                        Label("서브챕터 추가", systemImage: "plus")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    Task { await viewModel.deleteChapter(id: chapter.id) }
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground).opacity(0.5))
    }

    @ViewBuilder
    private func blockList(for chapter: Chapter) -> some View {
        let blocks = viewModel.blocks(for: chapter.id)
        if blocks.isEmpty {
            Text("블록이 없습니다")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        } else {
            ForEach(blocks) { block in
                BlockCard(block: block, chapterId: chapter.id, viewModel: viewModel)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
        }
    }
}
