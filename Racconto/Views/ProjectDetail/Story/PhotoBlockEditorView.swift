import SwiftUI

struct PhotoBlockEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let block: Block
    let chapterId: String
    var viewModel: StoryViewModel
    @State private var photos: [ChapterItem]
    @State private var showMoveSheet = false
    @State private var movingItem: ChapterItem? = nil

    init(block: Block, chapterId: String, viewModel: StoryViewModel) {
        self.block = block
        self.chapterId = chapterId
        self.viewModel = viewModel
        _photos = State(initialValue: block.photoItems)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 레이아웃 Picker
                Picker("레이아웃", selection: Binding(
                    get: { block.blockLayout },
                    set: { layout in
                        Task { await viewModel.changeBlockLayout(chapterId: chapterId, blockId: block.id, layout: layout) }
                    }
                )) {
                    Text("그리드").tag(ChapterItem.BlockLayout.grid)
                    Text("와이드").tag(ChapterItem.BlockLayout.wide)
                    Text("싱글").tag(ChapterItem.BlockLayout.single)
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                List {
                    ForEach(photos) { item in
                        HStack(spacing: 12) {
                            CachedImage(url: item.imageUrl, variant: .thumb, contentMode: .fill)
                                .frame(width: 56, height: 56)
                                .clipped()
                                .cornerRadius(6)

                            Text(item.caption ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Menu {
                                Button {
                                    movingItem = item
                                    showMoveSheet = true
                                } label: {
                                    Label("블록으로 이동", systemImage: "arrow.right.square")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteItem(chapterId: chapterId, itemId: item.id)
                                        photos.removeAll { $0.id == item.id }
                                    }
                                } label: {
                                    Label("블록에서 제거", systemImage: "minus.circle")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onMove { offsets, destination in
                        photos.move(fromOffsets: offsets, toOffset: destination)
                        Task {
                            await viewModel.reorderBlock(
                                chapterId: chapterId,
                                blockId: block.id,
                                itemIds: photos.map(\.id)
                            )
                        }
                    }
                }
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle("블록 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .sheet(isPresented: $showMoveSheet) {
                if let item = movingItem {
                    MoveBlockSheet(
                        item: item,
                        chapterId: chapterId,
                        currentBlockId: block.id,
                        viewModel: viewModel
                    ) {
                        dismiss()
                    }
                }
            }
        }
    }
}
