import SwiftUI
import UniformTypeIdentifiers

// MARK: - 드래그 세션 종료 감지 (StoryEditorView에서 이전)

final class DragEndAwareItemProvider: NSItemProvider {
    var onEnd: (() -> Void)?
    deinit { onEnd?() }
}

// MARK: - ChapterFormSheet (내부 공유용)

struct ChapterFormSheet: View {
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
                        onConfirm(
                            chapterTitle.trimmingCharacters(in: .whitespaces),
                            chapterDescription.trimmingCharacters(in: .whitespaces)
                        )
                        dismiss()
                    }
                    .disabled(chapterTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - BlockDropDelegate

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

// MARK: - ChapterDetailView

struct ChapterDetailView: View {
    var viewModel: StoryViewModel
    let project: Project
    @State private var editingChapter: Chapter? = nil
    @State private var showAddSub = false
    @State private var draggingId: String? = nil

    var body: some View {
        Group {
            if let ch = viewModel.currentChapter {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        chapterHeader(ch)
                        blockList(for: ch)
                    }
                    .padding(.bottom, 120)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        chapterMenu(ch)
                    }
                }
                .onDrop(of: [.text], isTargeted: nil) { _ in
                    draggingId = nil
                    return false
                }
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
                    if let current = viewModel.currentChapter {
                        let parentId = current.parentId == nil ? current.id : current.parentId!
                        ChapterFormSheet(title: "서브챕터 추가", confirmLabel: "생성") { title, desc in
                            Task { await viewModel.createChapter(title: title, description: desc.isEmpty ? nil : desc, parentId: parentId) }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "챕터가 없습니다",
                    systemImage: "text.book.closed",
                    description: Text("목차에서 챕터 추가를 눌러 시작하세요")
                )
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.currentChapter != nil {
                addTextFAB
            }
        }
    }

    // MARK: - FAB

    private var addTextFAB: some View {
        Button {
            guard let ch = viewModel.currentChapter else { return }
            Task { await viewModel.addTextItem(chapterId: ch.id, content: "") }
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

    // MARK: - 챕터 메뉴

    private func chapterMenu(_ ch: Chapter) -> some View {
        let isTop = ch.parentId == nil
        return Menu {
            Button {
                editingChapter = ch
            } label: {
                Label("챕터 수정", systemImage: "pencil")
            }
            if isTop {
                Button {
                    showAddSub = true
                } label: {
                    Label("서브챕터 추가", systemImage: "text.append")
                }
            }
            Divider()
            Button {
                Task { await viewModel.moveChapterUp(ch) }
            } label: {
                Label("위로 이동", systemImage: "chevron.up")
            }
            Button {
                Task { await viewModel.moveChapterDown(ch) }
            } label: {
                Label("아래로 이동", systemImage: "chevron.down")
            }
            Divider()
            Button(role: .destructive) {
                Task { await viewModel.deleteChapter(id: ch.id) }
            } label: {
                Label("삭제", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }

    // MARK: - 챕터 헤더

    private func chapterHeader(_ ch: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CHAPTER \(chapterLabel(for: ch))")
                .font(.system(size: 10, weight: .regular).leading(.tight))
                .tracking(0.6)
                .foregroundStyle(.tertiary)
            Text(ch.title)
                .font(.system(size: 28, design: .serif))
                .foregroundStyle(.primary)
                .kerning(-0.3)
            if let desc = ch.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundStyle(.secondary)
            }
            Divider()
                .padding(.leading, 0)
                .opacity(0.6)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private func chapterLabel(for ch: Chapter) -> String {
        for (idx, node) in viewModel.chapterTree.enumerated() {
            if node.parent.id == ch.id { return "\(idx + 1)" }
            for (subIdx, sub) in node.subs.enumerated() {
                if sub.id == ch.id { return "\(idx + 1).\(subIdx + 1)" }
            }
        }
        return "?"
    }

    // MARK: - 블록 리스트

    @ViewBuilder
    private func blockList(for ch: Chapter) -> some View {
        let blocks = viewModel.blocks(for: ch.id)
        if blocks.isEmpty {
            Text("블록이 없습니다")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        } else {
            VStack(spacing: 0) {
                ForEach(blocks) { block in
                    BlockCard(block: block, chapterId: ch.id, viewModel: viewModel)
                        .opacity(draggingId == block.id ? 0.4 : 1.0)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .onDrag {
                            draggingId = block.id
                            let provider = DragEndAwareItemProvider(object: block.id as NSString)
                            provider.onEnd = { DispatchQueue.main.async { draggingId = nil } }
                            return provider
                        }
                        .onDrop(of: [.text], delegate: BlockDropDelegate(
                            targetBlock: block,
                            chapterId: ch.id,
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
