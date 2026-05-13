import SwiftUI

struct ChapterOutlineSheet: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: StoryViewModel
    let project: Project
    var showDismissButton: Bool = true
    @State private var showAddChapter = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header
                    Divider()
                    if viewModel.chapterTree.isEmpty {
                        Text("챕터 없음")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.top, 16)
                    } else {
                        ForEach(Array(viewModel.chapterTree.enumerated()), id: \.element.parent.id) { idx, node in
                            chapterRow(node.parent, label: "\(idx + 1)", isSub: false)
                            ForEach(Array(node.subs.enumerated()), id: \.element.id) { subIdx, sub in
                                chapterRow(sub, label: "\(idx + 1).\(subIdx + 1)", isSub: true)
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { addChapterRow }
            .navigationTitle("목차")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showDismissButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") { dismiss() }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddChapter) {
            ChapterFormSheet(title: "새 챕터", confirmLabel: "생성") { title, desc in
                Task { await viewModel.createChapter(title: title, description: desc.isEmpty ? nil : desc) }
            }
        }
    }

    private func chapterRow(_ ch: Chapter, label: String, isSub: Bool) -> some View {
        let isActive = viewModel.currentChapterId == ch.id
        return Button {
            viewModel.currentChapterId = ch.id
            if showDismissButton { dismiss() }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 12)
                VStack(alignment: .leading, spacing: 1) {
                    Text("CHAPTER \(label)")
                        .font(.system(size: 10, weight: .regular).leading(.tight))
                        .tracking(0.6)
                        .foregroundStyle(.tertiary)
                    Text(ch.title)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let desc = ch.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(.caption, design: .serif).italic())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Text("\(photoCount(for: ch))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, isSub ? 36 : 14)
            .padding(.trailing, 14)
            .padding(.vertical, 10)
            .background(isActive ? Color.accentColor.opacity(0.07) : .clear)
            .overlay(alignment: .leading) {
                if isActive {
                    Rectangle().fill(Color.accentColor).frame(width: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func photoCount(for ch: Chapter) -> Int {
        (viewModel.itemsByChapter[ch.id] ?? []).filter { $0.itemType == .photo }.count
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.title)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(.primary)
            let totalPhotos = viewModel.itemsByChapter.values.flatMap { $0 }.filter { $0.itemType == .photo }.count
            let chapterCount = viewModel.chapterTree.count
            Text("\(totalPhotos) photos · \(chapterCount) chapters")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var addChapterRow: some View {
        Button {
            showAddChapter = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.caption)
                Text("챕터 추가")
                    .font(.system(.subheadline, design: .serif))
            }
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
