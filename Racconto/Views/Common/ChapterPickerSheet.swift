import SwiftUI

struct ChapterPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let projectId: String
    let onSelect: (Chapter) -> Void

    @State private var chapters: [Chapter] = []
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
                            onSelect(chapter)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                if chapter.parentId != nil {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(chapter.title)
                                    .foregroundStyle(.primary)
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
                if let ch: [Chapter] = try? await api.request("/chapters/?project_id=\(projectId)") {
                    let tree = ChapterTreeBuilder.buildTree(ch)
                    chapters = tree.flatMap { node in [node.parent] + node.subs }
                }
                isLoading = false
            }
        }
    }
}
