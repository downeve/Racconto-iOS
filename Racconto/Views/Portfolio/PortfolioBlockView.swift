import SwiftUI
import MarkdownUI

// 포트폴리오 아이템 그룹 (block_id 기준)
struct PortfolioBlock: Identifiable {
    let id: String
    let blockType: String?
    let blockLayout: String?
    let items: [PortfolioChapterItem]

    var isSideBySide: Bool { blockType == "side-left" || blockType == "side-right" }
    var photoItems: [PortfolioChapterItem] { items.filter { $0.itemType == "PHOTO" } }
    var textItem: PortfolioChapterItem? { items.first { $0.itemType == "TEXT" } }
}

func groupPortfolioItems(_ items: [PortfolioChapterItem]) -> [PortfolioBlock] {
    var result: [PortfolioBlock] = []
    var seen: Set<String> = []

    for item in items {
        guard let blockId = item.blockId else {
            result.append(PortfolioBlock(
                id: item.id ?? UUID().uuidString,
                blockType: item.blockType,
                blockLayout: item.blockLayout,
                items: [item]
            ))
            continue
        }
        if seen.contains(blockId) { continue }
        seen.insert(blockId)
        let blockItems = items.filter { $0.blockId == blockId }
        result.append(PortfolioBlock(
            id: blockId,
            blockType: blockItems.first?.blockType,
            blockLayout: blockItems.first(where: { $0.itemType == "PHOTO" })?.blockLayout,
            items: blockItems
        ))
    }
    return result
}

struct PortfolioBlockView: View {
    let items: [PortfolioChapterItem]
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var lightboxPhotos: [Photo] = []
    @State private var lightboxIndex: Int = 0
    @State private var showLightbox = false

    private var blocks: [PortfolioBlock] { groupPortfolioItems(items) }

    var body: some View {
        ForEach(blocks) { block in
            if block.isSideBySide {
                sideBySideBlock(block)
            } else if block.photoItems.isEmpty {
                if let text = block.textItem?.textContent {
                    Markdown(text)
                        .font(.custom("Georgia", size: 16))
                }
            } else {
                photoBlock(block)
            }
        }
        .fullScreenCover(isPresented: $showLightbox) {
            LightboxView(photos: lightboxPhotos, initialIndex: lightboxIndex, viewModel: nil, projectId: "")
        }
    }

    @ViewBuilder
    private func photoBlock(_ block: PortfolioBlock) -> some View {
        let cols: Int = {
            switch block.blockLayout {
            case "grid": return sizeClass == .regular ? 4 : 3
            case "wide": return 2
            default: return 1
            }
        }()
        let gridCols = Array(repeating: GridItem(.flexible(), spacing: 4), count: cols)
        LazyVGrid(columns: gridCols, spacing: 4) {
            ForEach(Array(block.photoItems.enumerated()), id: \.element.id) { idx, item in
                CachedImage(url: item.imageUrl, variant: .grid, contentMode: .fill)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .cornerRadius(2)
                    .onTapGesture { openLightbox(block: block, index: idx) }
            }
        }
    }

    @ViewBuilder
    private func sideBySideBlock(_ block: PortfolioBlock) -> some View {
        let isTextLeft = block.blockType == "side-left"
        Group {
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: 16) {
                    sideParts(block: block, isTextLeft: isTextLeft)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    sideParts(block: block, isTextLeft: isTextLeft)
                }
            }
        }
    }

    @ViewBuilder
    private func sideParts(block: PortfolioBlock, isTextLeft: Bool) -> some View {
        let photoCol = Group {
            ForEach(Array(block.photoItems.enumerated()), id: \.element.id) { idx, item in
                CachedImage(url: item.imageUrl, variant: .grid, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(4)
                    .onTapGesture { openLightbox(block: block, index: idx) }
            }
        }
        let textCol = Markdown(block.textItem?.textContent ?? "")
            .frame(maxWidth: .infinity, alignment: .leading)

        if isTextLeft {
            VStack { textCol }
            VStack { photoCol }
        } else {
            VStack { photoCol }
            VStack { textCol }
        }
    }

    private func openLightbox(block: PortfolioBlock, index: Int) {
        lightboxPhotos = block.photoItems.compactMap { item in
            guard let url = item.imageUrl else { return nil }
            return Photo(id: item.id ?? UUID().uuidString, projectId: "", imageUrl: url, caption: item.caption, order: 0, localMissing: nil)
        }
        lightboxIndex = index
        showLightbox = true
    }
}
