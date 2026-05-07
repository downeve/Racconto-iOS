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
        VStack(spacing: 0) {
            HStack {
                Button("취소") { dismiss() }
                Spacer()
                Text("블록으로 이동")
                    .font(.headline)
                Spacer()
                // 대칭 맞추기용 투명 버튼
                Button("취소") { }.opacity(0)
            }
            .padding()

            Divider()

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
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                                .cornerRadius(6)
                        }
                    }

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
                        .aspectRatio(1, contentMode: .fill)
                        .cornerRadius(6)
                    }
                }
                .padding()
            }
        }
    }
}
