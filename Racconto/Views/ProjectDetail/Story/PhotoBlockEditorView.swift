import SwiftUI
import UniformTypeIdentifiers

private struct PhotoDropDelegate: DropDelegate {
    let targetItem: ChapterItem
    @Binding var photos: [ChapterItem]
    @Binding var draggingItemId: String?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let draggingId = draggingItemId,
              draggingId != targetItem.id,
              let from = photos.firstIndex(where: { $0.id == draggingId }),
              let to = photos.firstIndex(where: { $0.id == targetItem.id }) else { return }
        photos.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingItemId = nil
        return true
    }
}

struct PhotoBlockEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let block: Block
    let chapterId: String
    var viewModel: StoryViewModel
    @State private var photos: [ChapterItem]
    @State private var showMoveSheet = false
    @State private var movingItem: ChapterItem?
    @State private var draggingItemId: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    init(block: Block, chapterId: String, viewModel: StoryViewModel) {
        self.block = block
        self.chapterId = chapterId
        self.viewModel = viewModel
        _photos = State(initialValue: block.photoItems)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photos) { item in
                            photoCell(item)
                        }
                    }
                    .padding(2)
                }
                .onChange(of: draggingItemId) { old, new in
                    guard old != nil, new == nil else { return }
                    let ids = photos.map(\.id)
                    Task { await viewModel.reorderBlock(chapterId: chapterId, blockId: block.id, itemIds: ids) }
                }
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
                    ) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func photoCell(_ item: ChapterItem) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                CachedImage(url: item.imageUrl, variant: .thumb, contentMode: .fill)
            }
            .clipped()
            .opacity(draggingItemId == item.id ? 0.4 : 1)
            .contextMenu {
                Button {
                    movingItem = item
                    showMoveSheet = true
                } label: {
                    Label("블록으로 이동", systemImage: "arrow.right.square")
                }
                Button(role: .destructive) {
                    Task {
                        await viewModel.deleteItem(chapterId: chapterId, itemId: item.id)
                        photos.removeAll { $0.id == item.id }
                    }
                } label: {
                    Label("블록에서 제거", systemImage: "minus.circle")
                }
            }
            .onDrag {
                draggingItemId = item.id
                let provider = DragEndAwareItemProvider(object: item.id as NSString)
                provider.onEnd = { DispatchQueue.main.async { draggingItemId = nil } }
                return provider
            }
            .onDrop(
                of: [UTType.text],
                delegate: PhotoDropDelegate(targetItem: item, photos: $photos, draggingItemId: $draggingItemId)
            )
    }
}
