import SwiftUI

struct MoveBlockSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: ChapterItem
    let chapterId: String
    let currentBlockId: String
    var viewModel: StoryViewModel
    let onMoved: () -> Void

    private var otherBlocks: [Block] {
        viewModel.blocks(for: chapterId).filter { $0.id != currentBlockId && !$0.photoItems.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(otherBlocks) { block in
                        Button {
                            Task {
                                await viewModel.moveToBlock(
                                    chapterId: chapterId,
                                    itemId: item.id,
                                    targetBlockId: block.id
                                )
                                onMoved()
                                dismiss()
                            }
                        } label: {
                            CachedImage(url: block.firstImageUrl, variant: .thumb, contentMode: .fill)
                                .aspectRatio(3/2, contentMode: .fill)
                                .clipped()
                                .cornerRadius(6)
                        }
                    }

                    // 새 블록
                    Button {
                        Task {
                            await viewModel.moveToBlock(
                                chapterId: chapterId,
                                itemId: item.id,
                                targetBlockId: "new"
                            )
                            onMoved()
                            dismiss()
                        }
                    } label: {
                        ZStack {
                            Color(.secondarySystemBackground)
                            VStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.title3)
                                Text("새 블록")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .aspectRatio(3/2, contentMode: .fill)
                        .cornerRadius(6)
                    }
                }
                .padding()
            }
            .navigationTitle("블록으로 이동")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}
