import SwiftUI

// MARK: - Selection Overlay

extension View {
    func selectionOverlay(isSelected: Bool, isSelecting: Bool) -> some View {
        self
            .overlay(alignment: .topTrailing) {
                if isSelecting {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.black.opacity(0.25))
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(.white, lineWidth: isSelected ? 0 : 1.5))
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(6)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2.5)
            )
    }
}

// MARK: - BlockCard

struct BlockCard: View {
    let block: Block
    let chapterId: String
    var viewModel: StoryViewModel
    @Binding var isSelecting: Bool
    @Binding var selectedItemIds: Set<String>
    @State private var showEditor = false
    @State private var showSideBySideSetup = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            blockHeader
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            if block.isSideBySide {
                sideBySidePreview
                    .frame(height: 80)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                    .contentShape(Rectangle())
                    .onTapGesture { if !isSelecting { showEditor = true } }
            } else if block.photoItems.isEmpty, let text = block.textItem?.textContent {
                Text(text.isEmpty ? "빈 텍스트 블록" : text)
                    .lineLimit(3)
                    .font(.callout)
                    .foregroundStyle(text.isEmpty ? .tertiary : .secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                    .contentShape(Rectangle())
                    .onTapGesture { if !isSelecting { showEditor = true } }
            } else {
                photoPreview
            }
        }
        .sheet(isPresented: $showEditor) {
            editorSheet
        }
        .sheet(isPresented: $showSideBySideSetup) {
            SideBySideSetupSheet(block: block, chapterId: chapterId, viewModel: viewModel)
        }
    }

    // MARK: - Header

    private var blockHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !block.isSideBySide && !block.photoItems.isEmpty {
                Text(photoEyebrow)
                    .font(.system(size: 10))
                    .tracking(0.5)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if !block.isSideBySide && !block.photoItems.isEmpty {
                layoutMenu
            }

            orderButtons

            if block.isSideBySide || block.textItem != nil {
                blockMenu
            }
        }
    }

    private var photoEyebrow: String {
        let count = block.photoItems.count
        let layoutName: String
        switch block.blockLayout {
        case .grid:   layoutName = "GRID"
        case .wide:   layoutName = "WIDE"
        case .single: layoutName = "SINGLE"
        }
        return "\(count) PHOTOS · \(layoutName)"
    }

    // MARK: - Photo Preview (full-bleed, layout-based)

    @ViewBuilder
    private var photoPreview: some View {
        switch block.blockLayout {
        case .grid:
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3),
                spacing: 2
            ) {
                ForEach(block.photoItems) { item in
                    photoCell(item, ratio: 3 / 2)
                }
            }
            .padding(.bottom, 2)

        case .wide:
            VStack(spacing: 2) {
                ForEach(block.photoItems) { item in
                    photoCell(item, ratio: 12 / 5)
                }
            }
            .padding(.bottom, 2)

        case .single:
            if let item = block.photoItems.first {
                photoCell(item, ratio: 14 / 9)
                    .padding(.bottom, 2)
            }
        }
    }

    private func photoCell(_ item: ChapterItem, ratio: CGFloat) -> some View {
        Color.clear
            .aspectRatio(ratio, contentMode: .fit)
            .overlay {
                CachedImage(url: item.imageUrl, variant: .thumb, contentMode: .fill)
            }
            .clipped()
            .selectionOverlay(
                isSelected: selectedItemIds.contains(item.id),
                isSelecting: isSelecting
            )
            .onTapGesture {
                if isSelecting {
                    if selectedItemIds.contains(item.id) {
                        selectedItemIds.remove(item.id)
                    } else {
                        selectedItemIds.insert(item.id)
                    }
                } else {
                    showEditor = true
                }
            }
    }

    // MARK: - Side-by-side preview

    private var sideBySidePreview: some View {
        HStack(spacing: 8) {
            if block.blockType == "side-right" {
                photoColumn
                textColumn
            } else {
                textColumn
                photoColumn
            }
        }
        .clipped()
    }

    private var photoColumn: some View {
        CachedImage(url: block.firstImageUrl, variant: .thumb, contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .cornerRadius(4)
    }

    private var textColumn: some View {
        Text(block.textItem?.textContent ?? "")
            .lineLimit(3)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Menus

    private var layoutMenu: some View {
        Menu {
            ForEach([ChapterItem.BlockLayout.grid, .wide, .single], id: \.self) { layout in
                Button {
                    Task { await viewModel.changeBlockLayout(chapterId: chapterId, blockId: block.id, layout: layout) }
                } label: {
                    if block.blockLayout == layout {
                        Label(layoutLabel(layout), systemImage: "checkmark")
                    } else {
                        Text(layoutLabel(layout))
                    }
                }
            }
        } label: {
            Text(layoutLabel(block.blockLayout))
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(4)
        }
    }

    private var orderButtons: some View {
        HStack(spacing: 2) {
            Button {
                Task { await viewModel.moveBlockUp(chapterId: chapterId, blockId: block.id) }
            } label: {
                Image(systemName: "chevron.up").font(.caption)
            }
            Button {
                Task { await viewModel.moveBlockDown(chapterId: chapterId, blockId: block.id) }
            } label: {
                Image(systemName: "chevron.down").font(.caption)
            }
        }
        .foregroundStyle(.secondary)
    }

    private var blockMenu: some View {
        Menu {
            if sizeClass == .regular {
                if block.isSideBySide {
                    if let item = block.textItem {
                        Button {
                            Task { await viewModel.cancelSideBySide(chapterId: chapterId, textItemId: item.id) }
                        } label: {
                            Label("나란히 배치 해제", systemImage: "rectangle.split.2x1.slash")
                        }
                        Divider()
                    }
                } else {
                    let hasCounterpart = block.photoItems.isEmpty
                        ? !viewModel.blocks(for: chapterId).filter { !$0.isSideBySide && !$0.photoItems.isEmpty }.isEmpty
                        : !viewModel.blocks(for: chapterId).filter { !$0.isSideBySide && $0.textItem != nil }.isEmpty
                    if hasCounterpart {
                        Button { showSideBySideSetup = true } label: {
                            Label("나란히 배치", systemImage: "rectangle.split.2x1")
                        }
                        Divider()
                    }
                }
            }
            if let item = block.textItem {
                Button(role: .destructive) {
                    Task { await viewModel.deleteItem(chapterId: chapterId, itemId: item.id) }
                } label: {
                    Label("블록 삭제", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
    }

    // MARK: - Editor Sheet

    @ViewBuilder
    private var editorSheet: some View {
        if block.isSideBySide {
            SideBySideBlockView(block: block, chapterId: chapterId, viewModel: viewModel)
        } else if block.photoItems.isEmpty {
            TextBlockEditorView(block: block, chapterId: chapterId, viewModel: viewModel)
        } else {
            PhotoBlockEditorView(
                block: block,
                chapterId: chapterId,
                viewModel: viewModel,
                isSelecting: $isSelecting
            )
        }
    }

    private func layoutLabel(_ layout: ChapterItem.BlockLayout) -> String {
        switch layout {
        case .grid:   return "그리드"
        case .wide:   return "와이드"
        case .single: return "싱글"
        }
    }
}
