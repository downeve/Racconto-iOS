import SwiftUI

struct BlockCard: View {
    let block: Block
    let chapterId: String
    var viewModel: StoryViewModel
    @State private var showEditor = false
    @State private var showSideBySideSetup = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if !block.isSideBySide && !block.photoItems.isEmpty {
                    layoutMenu
                }

                orderButtons

                if block.isSideBySide || block.textItem != nil {
                    blockMenu
                }
            }

            // Content preview — 이 영역 탭 시 편집 화면 열기
            Group {
                if block.isSideBySide {
                    sideBySidePreview
                } else if block.photoItems.isEmpty, let text = block.textItem?.textContent {
                    Text(text.isEmpty ? "빈 텍스트 블록" : text)
                        .lineLimit(2)
                        .font(.callout)
                        .foregroundStyle(text.isEmpty ? .tertiary : .secondary)
                } else {
                    photoPreview
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { showEditor = true }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .sheet(isPresented: $showEditor) {
            editorSheet
        }
        .sheet(isPresented: $showSideBySideSetup) {
            SideBySideSetupSheet(block: block, chapterId: chapterId, viewModel: viewModel)
        }
    }

    // MARK: - Sub-views

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
                Image(systemName: "chevron.up")
                    .font(.caption)
            }
            Button {
                Task { await viewModel.moveBlockDown(chapterId: chapterId, blockId: block.id) }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.caption)
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
                        Button {
                            showSideBySideSetup = true
                        } label: {
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

    private var photoPreview: some View {
        let photos = Array(block.photoItems.prefix(3))
        let remaining = max(0, block.photoItems.count - 3)
        return HStack(spacing: 4) {
            ForEach(photos) { item in
                CachedImage(url: item.imageUrl, variant: .thumb, contentMode: .fill)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(4)
            }
            if remaining > 0 {
                ZStack {
                    Color(.tertiarySystemBackground)
                    Text("+\(remaining)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .cornerRadius(4)
            }
        }
    }

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
        .frame(height: 56)
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

    @ViewBuilder
    private var editorSheet: some View {
        if block.isSideBySide {
            SideBySideBlockView(block: block, chapterId: chapterId, viewModel: viewModel)
        } else if block.photoItems.isEmpty {
            TextBlockEditorView(block: block, chapterId: chapterId, viewModel: viewModel)
        } else {
            PhotoBlockEditorView(block: block, chapterId: chapterId, viewModel: viewModel)
        }
    }

    private func layoutLabel(_ layout: ChapterItem.BlockLayout) -> String {
        switch layout {
        case .grid: return "그리드"
        case .wide: return "와이드"
        case .single: return "싱글"
        }
    }
}
