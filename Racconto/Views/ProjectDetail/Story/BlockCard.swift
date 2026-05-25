import SwiftUI
import MarkdownUI

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
                Rectangle()
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
        Group {
            if block.isSideBySide {
                sbsBlock
            } else if block.photoItems.isEmpty {
                textBlock
            } else {
                photoBlock
            }
        }
        .sheet(isPresented: $showEditor) { editorSheet }
        .sheet(isPresented: $showSideBySideSetup) {
            SideBySideSetupSheet(block: block, chapterId: chapterId, viewModel: viewModel)
        }
    }

    // MARK: - Photo Block (Editorial B)

    private var photoBlock: some View {
        photoGrid
            .blockCardChrome(
                leadingEyebrow: "Photographs · № \(String(format: "%02d", block.photoItems.count))",
                trailingEyebrow: layoutKey,
                onMoveUp:   { Task { await viewModel.moveBlockUp(chapterId: chapterId, blockId: block.id) } },
                onMoveDown: { Task { await viewModel.moveBlockDown(chapterId: chapterId, blockId: block.id) } }
            )
            .contentShape(Rectangle())
            .onTapGesture { if !isSelecting { showEditor = true } }
            .contextMenu { photoContextMenu }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("사진 블록, \(block.photoItems.count)장, \(layoutKey)")
    }

    private var layoutKey: String {
        switch block.blockLayout {
        case .grid:   "Grid"
        case .wide:   "Wide"
        case .single: "Single"
        }
    }

    @ViewBuilder
    private var photoGrid: some View {
        switch block.blockLayout {
        case .grid:
            let cols = sizeClass == .regular ? 4 : 3
            LazyVGrid(columns: gridCols(cols), spacing: StoryTokens.photoGap) {
                ForEach(block.photoItems) { item in photoCell(item, ratio: 1) }
            }
        case .wide:
            if sizeClass == .regular {
                LazyVGrid(columns: gridCols(2), spacing: StoryTokens.photoGap) {
                    ForEach(block.photoItems) { item in photoCell(item, ratio: 3.0 / 2.0) }
                }
            } else {
                VStack(spacing: StoryTokens.photoGap) {
                    ForEach(block.photoItems) { item in photoCell(item, ratio: 12.0 / 5.0) }
                }
            }
        case .single:
            if let item = block.photoItems.first {
                photoCell(item, ratio: 14.0 / 9.0)
            }
        }
    }

    private func gridCols(_ n: Int) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: StoryTokens.photoGap), count: n)
    }

    private func photoCell(_ item: ChapterItem, ratio: CGFloat) -> some View {
        Color.clear
            .aspectRatio(ratio, contentMode: .fit)
            .overlay { CachedImage(url: item.imageUrl, variant: .thumb, contentMode: .fill) }
            .clipShape(RoundedRectangle(cornerRadius: StoryTokens.photoRadius))
            .selectionOverlay(isSelected: selectedItemIds.contains(item.id), isSelecting: isSelecting)
            .onTapGesture {
                if isSelecting {
                    if selectedItemIds.contains(item.id) { selectedItemIds.remove(item.id) }
                    else { selectedItemIds.insert(item.id) }
                } else {
                    showEditor = true
                }
            }
    }

    @ViewBuilder
    private var photoContextMenu: some View {
        Section {
            Button { Task { await viewModel.moveBlockUp(chapterId: chapterId, blockId: block.id) } }
                label: { Label("위로 이동", systemImage: "chevron.up") }
            Button { Task { await viewModel.moveBlockDown(chapterId: chapterId, blockId: block.id) } }
                label: { Label("아래로 이동", systemImage: "chevron.down") }
        }
        Section("레이아웃") {
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
        }
        if hasSideBySidePartner {
            Button { showSideBySideSetup = true }
                label: { Label("나란히 배치", systemImage: "rectangle.split.2x1") }
        }
        Divider()
        Button(role: .destructive) {
            Task {
                for item in block.items {
                    await viewModel.deleteItem(chapterId: chapterId, itemId: item.id)
                }
            }
        } label: { Label("블록 삭제", systemImage: "trash") }
    }

    // MARK: - Text Block

    private var textBlock: some View {
        let content = block.textItem?.textContent ?? ""
        return Group {
            if content.isEmpty {
                Text("빈 텍스트 블록")
                    .font(.storyBodySerif)
                    .foregroundStyle(StoryTokens.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Markdown(preprocessMarkdown(content))
                    .markdownTextStyle {
                        FontFamily(.custom("Georgia"))
                        FontSize(15)
                    }
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .blockCardChrome(
            leadingEyebrow: "Text",
            onMoveUp:   { Task { await viewModel.moveBlockUp(chapterId: chapterId, blockId: block.id) } },
            onMoveDown: { Task { await viewModel.moveBlockDown(chapterId: chapterId, blockId: block.id) } }
        )
        .contextMenu { textContextMenu }
        .contentShape(Rectangle())
        .onTapGesture { if !isSelecting { showEditor = true } }
    }

    @ViewBuilder
    private var textContextMenu: some View {
        Section {
            Button { Task { await viewModel.moveBlockUp(chapterId: chapterId, blockId: block.id) } }
                label: { Label("위로 이동", systemImage: "chevron.up") }
            Button { Task { await viewModel.moveBlockDown(chapterId: chapterId, blockId: block.id) } }
                label: { Label("아래로 이동", systemImage: "chevron.down") }
        }
        if hasSideBySidePartner {
            Button { showSideBySideSetup = true }
                label: { Label("나란히 배치", systemImage: "rectangle.split.2x1") }
        }
        Divider()
        if let item = block.textItem {
            Button(role: .destructive) {
                Task { await viewModel.deleteItem(chapterId: chapterId, itemId: item.id) }
            } label: { Label("블록 삭제", systemImage: "trash") }
        }
    }

    // MARK: - SBS Block

    private var sbsBlock: some View {
        StackedSideBySideBlock(
            block: block,
            chapterId: chapterId,
            viewModel: viewModel,
            isSelecting: $isSelecting
        )
    }

    // MARK: - Shared Helpers

    private var hasSideBySidePartner: Bool {
        let blocks = viewModel.blocks(for: chapterId)
        if block.photoItems.isEmpty {
            return blocks.contains { !$0.isSideBySide && !$0.photoItems.isEmpty && $0.id != block.id }
        } else {
            return blocks.contains { !$0.isSideBySide && $0.textItem != nil && $0.id != block.id }
        }
    }

    private func layoutLabel(_ layout: ChapterItem.BlockLayout) -> String {
        switch layout {
        case .grid:   "그리드"
        case .wide:   "와이드"
        case .single: "싱글"
        }
    }

    @ViewBuilder
    private var editorSheet: some View {
        if block.photoItems.isEmpty {
            TextBlockEditorView(block: block, chapterId: chapterId, viewModel: viewModel)
        } else {
            PhotoBlockEditorView(block: block, chapterId: chapterId, viewModel: viewModel, isSelecting: $isSelecting)
        }
    }
}

// MARK: - StackedSideBySideBlock

struct StackedSideBySideBlock: View {
    let block: Block
    let chapterId: String
    var viewModel: StoryViewModel
    @Binding var isSelecting: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showEditor = false

    private var isTextLeft: Bool { block.blockType == "side-left" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Eyebrow(text: "Side-by-side · \(isTextLeft ? "text · photo" : "photo · text")")
                Spacer()
                if sizeClass == .regular {
                    iconBtn("chevron.up")   { Task { await viewModel.moveBlockUp(chapterId: chapterId, blockId: block.id) } }
                    iconBtn("chevron.down") { Task { await viewModel.moveBlockDown(chapterId: chapterId, blockId: block.id) } }
                }
            }

            if sizeClass == .regular {
                HStack(alignment: .top, spacing: 14) { sbsContent }
            } else {
                VStack(alignment: .leading, spacing: 10) { sbsContent }
            }
        }
        .padding(.horizontal, StoryTokens.blockPadH)
        .padding(.vertical, StoryTokens.blockPadV)
        .overlay(alignment: .top) {
            Rectangle().fill(StoryTokens.line).frame(height: 0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture { if !isSelecting { showEditor = true } }
        .contextMenu { sbsContextMenu }
        .sheet(isPresented: $showEditor) {
            SideBySideBlockView(block: block, chapterId: chapterId, viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var sbsContent: some View {
        if isTextLeft { textSection; photoSection }
        else { photoSection; textSection }
    }

    private var textSection: some View {
        let content = block.textItem?.textContent ?? ""
        return Group {
            if content.isEmpty {
                Text("텍스트 없음")
                    .font(.storyBodySerif)
                    .foregroundStyle(StoryTokens.faint)
            } else {
                // 단일 텍스트 블록과 동일하게 마크다운 렌더 (preprocessMarkdown으로 right-flanking 보정)
                Markdown(preprocessMarkdown(content))
                    .markdownTextStyle {
                        FontFamily(.custom("Georgia"))
                        FontSize(15)
                    }
                    .foregroundStyle(StoryTokens.inkSoft)
                    .lineLimit(sizeClass == .regular ? 8 : 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var photoSection: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay { CachedImage(url: block.firstImageUrl, variant: .thumb, contentMode: .fill) }
                .clipShape(RoundedRectangle(cornerRadius: StoryTokens.photoRadius))
            HStack(spacing: 4) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                Text(isTextLeft ? "TEXT ◂ PHOTO" : "PHOTO ▸ TEXT")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.2)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial)
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(8)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var sbsContextMenu: some View {
        Section {
            Button { Task { await viewModel.moveBlockUp(chapterId: chapterId, blockId: block.id) } }
                label: { Label("위로 이동", systemImage: "chevron.up") }
            Button { Task { await viewModel.moveBlockDown(chapterId: chapterId, blockId: block.id) } }
                label: { Label("아래로 이동", systemImage: "chevron.down") }
        }
        if let textItem = block.textItem {
            Button(role: .destructive) {
                Task { await viewModel.cancelSideBySide(chapterId: chapterId, textItemId: textItem.id) }
            } label: { Label("나란히 배치 해제", systemImage: "rectangle.split.2x1.slash") }
        }
        Divider()
        if let item = block.textItem {
            Button(role: .destructive) {
                Task { await viewModel.deleteItem(chapterId: chapterId, itemId: item.id) }
            } label: { Label("블록 삭제", systemImage: "trash") }
        }
    }

    private func iconBtn(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(StoryTokens.muted)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}
