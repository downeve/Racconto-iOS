import SwiftUI

struct ChapterOutlineSheet: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: StoryViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(viewModel.chapterTree.enumerated()), id: \.element.parent.id) { idx, node in
                    Section {
                        chapterRow(node.parent, label: "\(idx + 1)")
                        ForEach(Array(node.subs.enumerated()), id: \.element.id) { subIdx, sub in
                            chapterRow(sub, label: "\(idx + 1).\(subIdx + 1)")
                                .listRowInsets(.init(top: 6, leading: 44, bottom: 6, trailing: 16))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("목차")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func chapterRow(_ ch: Chapter, label: String) -> some View {
        Button {
            viewModel.expandedChapterId = ch.id
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Text("Ch. \(label)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(width: 36, alignment: .leading)
                Text(ch.title)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\((viewModel.itemsByChapter[ch.id] ?? []).filter { $0.itemType == .photo }.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}
