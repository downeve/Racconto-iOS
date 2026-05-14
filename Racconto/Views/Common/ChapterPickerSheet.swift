import SwiftUI

struct ChapterPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let projectId: String
    let onSelect: (Chapter, Set<String>) -> Void
    var photoId: String? = nil

    @State private var chapters: [Chapter] = []
    @State private var chapterNumbers: [String: String] = [:]
    @State private var addedChapterIds: Set<String> = []
    @State private var isLoading = false
    private let api = RaccontoAPI.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(chapters) { chapter in
                        Button {
                            onSelect(chapter, addedChapterIds)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                if chapter.parentId != nil {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    if let num = chapterNumbers[chapter.id] {
                                        Text("챕터 \(num)")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Text(chapter.title)
                                        .foregroundStyle(.primary)
                                }
                                Spacer()
                                if addedChapterIds.contains(chapter.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.body)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("챕터 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .task {
                isLoading = true
                defer { isLoading = false }

                guard let ch: [Chapter] = try? await api.request("/chapters/?project_id=\(projectId)") else { return }

                let tree = ChapterTreeBuilder.buildTree(ch)
                var numbers: [String: String] = [:]
                for (topIdx, node) in tree.enumerated() {
                    numbers[node.parent.id] = "\(topIdx + 1)"
                    for (subIdx, sub) in node.subs.enumerated() {
                        numbers[sub.id] = "\(topIdx + 1).\(subIdx + 1)"
                    }
                }
                chapters = tree.flatMap { node in [node.parent] + node.subs }
                chapterNumbers = numbers

                guard let pid = photoId else { return }
                await withTaskGroup(of: (String, Bool).self) { group in
                    for chapter in chapters {
                        group.addTask {
                            let items: [ChapterItem]? = try? await api.request("/chapters/\(chapter.id)/items")
                            let has = items?.contains { $0.photoId == pid } ?? false
                            return (chapter.id, has)
                        }
                    }
                    for await (id, has) in group where has {
                        addedChapterIds.insert(id)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
