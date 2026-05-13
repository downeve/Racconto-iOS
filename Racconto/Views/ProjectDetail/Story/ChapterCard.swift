import SwiftUI
import UniformTypeIdentifiers

// MARK: - 드래그 세션 종료 감지

final class DragEndAwareItemProvider: NSItemProvider {
    var onEnd: (() -> Void)?
    deinit { onEnd?() }
}

// MARK: - BlockDropDelegate

struct BlockDropDelegate: DropDelegate {
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

// MARK: - ChapterCard

struct ChapterCard: View {
    let chapter: Chapter
    let label: String
    let isSub: Bool
    var viewModel: StoryViewModel
    let project: Project

    @State private var editingChapter: Chapter? = nil
    @State private var showAddSub = false
    @State private var draggingId: String? = nil

    private var isExpanded: Bool { viewModel.expandedChapterId == chapter.id }
    private var photos: [ChapterItem] {
        (viewModel.itemsByChapter[chapter.id] ?? []).filter { $0.itemType == .photo }
    }
    private var heroPhotoURL: String? { photos.first?.imageUrl }

    var body: some View {
        Group {
            if isExpanded {
                expandedCard
            } else {
                collapsedCard
            }
        }
        .padding(.horizontal, 12)
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }

    // MARK: collapsed

    private var collapsedCard: some View {
        Button {
            viewModel.toggleExpanded(chapter.id)
        } label: {
            HStack(spacing: 0) {
                Group {
                    if let url = heroPhotoURL {
                        CachedImage(url: url, variant: .thumb, contentMode: .fill)
                    } else {
                        Color(.tertiarySystemBackground)
                    }
                }
                .frame(width: 100, height: 88)
                .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text("CHAPTER \(label)")
                        .font(.system(size: 10))
                        .tracking(0.6)
                        .foregroundStyle(.tertiary)
                    Text(chapter.title)
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    HStack {
                        Text("\(photos.count) photos")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 88)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color(.separator), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: expanded

    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let desc = chapter.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
            }
            ForEach(viewModel.blocks(for: chapter.id)) { block in
                BlockCard(block: block, chapterId: chapter.id, viewModel: viewModel)
                    .opacity(draggingId == block.id ? 0.4 : 1.0)
                    .padding(.vertical, 6)
                    .onDrag {
                        draggingId = block.id
                        let provider = DragEndAwareItemProvider(object: block.id as NSString)
                        provider.onEnd = { DispatchQueue.main.async { draggingId = nil } }
                        return provider
                    }
                    .onDrop(of: [.text], delegate: BlockDropDelegate(
                        targetBlock: block,
                        chapterId: chapter.id,
                        viewModel: viewModel,
                        draggingId: $draggingId
                    ))
            }
            insertHint
        }
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 14, y: 2)
        .onDrop(of: [.text], isTargeted: nil) { _ in
            draggingId = nil
            return false
        }
        .sheet(item: $editingChapter) { ch in
            ChapterFormSheet(
                title: "챕터 수정",
                confirmLabel: "저장",
                initialTitle: ch.title,
                initialDescription: ch.description ?? ""
            ) { title, desc in
                Task { await viewModel.updateChapter(id: ch.id, title: title, description: desc.isEmpty ? nil : desc) }
            }
        }
        .sheet(isPresented: $showAddSub) {
            ChapterFormSheet(title: "서브챕터 추가", confirmLabel: "생성") { title, desc in
                Task { await viewModel.createChapter(title: title, description: desc.isEmpty ? nil : desc, parentId: chapter.id) }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CHAPTER \(label)")
                    .font(.system(size: 10))
                    .tracking(0.6)
                    .foregroundStyle(.tertiary)
                Text(chapter.title)
                    .font(.system(size: 24, design: .serif))
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 8)
            chapterMenu
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var chapterMenu: some View {
        Menu {
            Button { editingChapter = chapter } label: {
                Label("수정", systemImage: "pencil")
            }
            if !isSub {
                Button { showAddSub = true } label: {
                    Label("서브챕터 추가", systemImage: "plus")
                }
            }
            Section {
                Button { Task { await viewModel.moveChapterUp(chapter) } } label: {
                    Label("위로 이동", systemImage: "chevron.up")
                }
                Button { Task { await viewModel.moveChapterDown(chapter) } } label: {
                    Label("아래로 이동", systemImage: "chevron.down")
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
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
        }
    }

    private var insertHint: some View {
        Group {
            if viewModel.blocks(for: chapter.id).isEmpty {
                Text("빈 챕터입니다. 우하단 + 버튼으로 블록을 추가하세요.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
            }
        }
    }
}
