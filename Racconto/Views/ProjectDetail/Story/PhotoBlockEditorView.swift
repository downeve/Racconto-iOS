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
    @Binding var isSelecting: Bool
    @State private var photos: [ChapterItem]
    @State private var showMoveSheet = false
    @State private var movingItem: ChapterItem?
    @State private var draggingItemId: String?
    @State private var selectedIds: Set<String> = []
    @State private var isEditorSelecting = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    init(block: Block, chapterId: String, viewModel: StoryViewModel, isSelecting: Binding<Bool>) {
        self.block = block
        self.chapterId = chapterId
        self.viewModel = viewModel
        self._isSelecting = isSelecting
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
                    Label("그리드", systemImage: "square.grid.3x3").tag(ChapterItem.BlockLayout.grid)
                    Label("와이드", systemImage: "rectangle.grid.1x2").tag(ChapterItem.BlockLayout.wide)
                    Label("싱글", systemImage: "rectangle").tag(ChapterItem.BlockLayout.single)
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
            .safeAreaInset(edge: .bottom) {
                if isEditorSelecting && !selectedIds.isEmpty {
                    editorBottomToolbar
                }
            }
            .navigationTitle("블록 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditorSelecting {
                        Button("취소") {
                            isEditorSelecting = false
                            selectedIds = []
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isEditorSelecting {
                        Button("완료") {
                            isEditorSelecting = false
                            selectedIds = []
                        }
                    } else {
                        Button("완료") { dismiss() }
                    }
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

    // MARK: - Bottom Toolbar

    private var editorBottomToolbar: some View {
        HStack(spacing: 0) {
            toolbarBtn("그리드", systemImage: "square.grid.3x3") {
                Task { await viewModel.changeBlockLayout(chapterId: chapterId, blockId: block.id, layout: .grid) }
            }
            toolbarBtn("와이드", systemImage: "rectangle.grid.1x2") {
                Task { await viewModel.changeBlockLayout(chapterId: chapterId, blockId: block.id, layout: .wide) }
            }
            toolbarBtn("싱글", systemImage: "rectangle") {
                Task { await viewModel.changeBlockLayout(chapterId: chapterId, blockId: block.id, layout: .single) }
            }
            Divider().frame(height: 28)
            toolbarBtn("이동", systemImage: "arrow.right.square") {
                if let first = photos.first(where: { selectedIds.contains($0.id) }) {
                    movingItem = first
                    showMoveSheet = true
                }
            }
            toolbarBtn("삭제", systemImage: "trash", role: .destructive) {
                let toDelete = selectedIds
                Task {
                    for id in toDelete {
                        await viewModel.deleteItem(chapterId: chapterId, itemId: id)
                    }
                    photos.removeAll { toDelete.contains($0.id) }
                    selectedIds = []
                    isEditorSelecting = false
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private func toolbarBtn(
        _ label: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundStyle(role == .destructive ? .red : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Photo Cell

    @ViewBuilder
    private func photoCell(_ item: ChapterItem) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                CachedImage(url: item.imageUrl, variant: .thumb, contentMode: .fill)
            }
            .clipped()
            .opacity(draggingItemId == item.id ? 0.4 : 1)
            .selectionOverlay(isSelected: selectedIds.contains(item.id), isSelecting: isEditorSelecting)
            .onTapGesture {
                if isEditorSelecting {
                    if selectedIds.contains(item.id) { selectedIds.remove(item.id) }
                    else { selectedIds.insert(item.id) }
                }
            }
            .contextMenu {
                Button {
                    isEditorSelecting = true
                    selectedIds.insert(item.id)
                } label: {
                    Label("선택", systemImage: "checkmark.circle")
                }
                Button {
                    isSelecting = true
                    dismiss()
                } label: {
                    Label("스토리 선택 모드", systemImage: "photo.stack")
                }
                Divider()
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
