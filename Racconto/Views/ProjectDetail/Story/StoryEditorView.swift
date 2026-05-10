import SwiftUI
import UniformTypeIdentifiers

// MARK: - 챕터 생성/수정 폼 시트

private struct ChapterFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let confirmLabel: String
    let initialTitle: String
    let initialDescription: String
    let onConfirm: (String, String) -> Void

    @State private var chapterTitle: String
    @State private var chapterDescription: String

    init(title: String, confirmLabel: String, initialTitle: String = "", initialDescription: String = "", onConfirm: @escaping (String, String) -> Void) {
        self.title = title
        self.confirmLabel = confirmLabel
        self.initialTitle = initialTitle
        self.initialDescription = initialDescription
        self.onConfirm = onConfirm
        _chapterTitle = State(initialValue: initialTitle)
        _chapterDescription = State(initialValue: initialDescription)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("제목") {
                    TextField("챕터 제목", text: $chapterTitle)
                }
                Section("설명 (선택)") {
                    TextField("챕터 설명", text: $chapterDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmLabel) {
                        onConfirm(chapterTitle.trimmingCharacters(in: .whitespaces), chapterDescription.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .disabled(chapterTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - StoryEditorView

struct StoryEditorView: View {
    var viewModel: StoryViewModel
    let project: Project
    var scrollToChapterId: Binding<String?> = .constant(nil)
    @State private var showAddChapter = false
    @State private var showChapterPicker = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if viewModel.chapterTree.isEmpty {
                            ContentUnavailableView("챕터가 없습니다", systemImage: "text.book.closed")
                                .padding(.top, 60)
                        } else {
                            ForEach(Array(viewModel.chapterTree.enumerated()), id: \.element.parent.id) { topIdx, node in
                                ChapterSectionView(node: node, topIndex: topIdx + 1, viewModel: viewModel, project: project)
                                    .id(node.parent.id)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
                .onChange(of: scrollToChapterId.wrappedValue) { _, id in
                    guard let id else { return }
                    withAnimation { proxy.scrollTo(id, anchor: .top) }
                    scrollToChapterId.wrappedValue = nil
                }
            }

            // FAB: 챕터 추가
            Button {
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
        .sheet(isPresented: $showAddChapter) {
            ChapterFormSheet(title: String(localized: "새 챕터"), confirmLabel: String(localized: "생성")) { title, desc in
                Task { await viewModel.createChapter(title: title, description: desc.isEmpty ? nil : desc) }
            }
        }
        .sheet(isPresented: $showChapterPicker) {
            ChapterPickerSheet(projectId: project.id) { chapter, _ in
                Task { await viewModel.addTextItem(chapterId: chapter.id, content: "") }
            }
        }
    }
}

// MARK: - ChapterSectionView

private struct BlockDropDelegate: DropDelegate {
    let targetBlock: Block
    let chapterId: String
    var viewModel: StoryViewModel
    @Binding var draggingId: String?

    func performDrop(info: DropInfo) -> Bool {
        Task { await viewModel.syncBlockOrder(chapterId: chapterId) }
        draggingId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let id = draggingId, id != targetBlock.id else { return }
        let blocks = viewModel.blocks(for: chapterId)
        guard let from = blocks.firstIndex(where: { $0.id == id }),
              let to = blocks.firstIndex(where: { $0.id == targetBlock.id }) else { return }
        viewModel.moveBlockLocally(chapterId: chapterId, from: from, to: to)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

struct ChapterSectionView: View {
    let node: ChapterNode
    let topIndex: Int
    var viewModel: StoryViewModel
    let project: Project
    @State private var editingChapter: Chapter? = nil
    @State private var showAddSub = false
    @State private var draggingId: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 최상위 챕터 헤더
            chapterHeader(chapter: node.parent, isTop: true, label: "\(topIndex)")

            // 최상위 챕터 블록
            blockList(for: node.parent)

            // 서브챕터
            ForEach(Array(node.subs.enumerated()), id: \.element.id) { subIdx, sub in
                VStack(alignment: .leading, spacing: 0) {
                    chapterHeader(chapter: sub, isTop: false, label: "\(topIndex).\(subIdx + 1)")
                    blockList(for: sub)
                }
                .padding(.leading, 16)
                .id(sub.id)
            }
        }
        .padding(.bottom, 8)
        .sheet(item: $editingChapter) { chapter in
            ChapterFormSheet(
                title: "챕터 수정",
                confirmLabel: "저장",
                initialTitle: chapter.title,
                initialDescription: chapter.description ?? ""
            ) { title, desc in
                Task { await viewModel.updateChapter(id: chapter.id, title: title, description: desc.isEmpty ? nil : desc) }
            }
        }
        .sheet(isPresented: $showAddSub) {
            ChapterFormSheet(title: String(localized: "서브챕터 추가"), confirmLabel: String(localized: "생성")) { title, desc in
                Task { await viewModel.createChapter(title: title, description: desc.isEmpty ? nil : desc, parentId: node.parent.id) }
            }
        }
    }

    @ViewBuilder
    private func chapterHeader(chapter: Chapter, isTop: Bool, label: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Ch. \(label).")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(chapter.title)
                    .font(isTop ? .headline : .subheadline)
                    .fontWeight(isTop ? .semibold : .medium)
                    .foregroundStyle(isTop ? .primary : .secondary)
                if let desc = chapter.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

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
                    editingChapter = chapter
                } label: {
                    Label("수정", systemImage: "pencil")
                }
                if isTop {
                    Button {
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
            VStack(spacing: 0) {
                ForEach(blocks) { block in
                    BlockCard(block: block, chapterId: chapter.id, viewModel: viewModel)
                        .opacity(draggingId == block.id ? 0.4 : 1.0)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .onDrag {
                            draggingId = block.id
                            return NSItemProvider(object: block.id as NSString)
                        }
                        .onDrop(of: [.text], delegate: BlockDropDelegate(
                            targetBlock: block,
                            chapterId: chapter.id,
                            viewModel: viewModel,
                            draggingId: $draggingId
                        ))
                }
            }
            .onDrop(of: [.text], isTargeted: nil) { _ in
                draggingId = nil
                return false
            }
        }
    }
}