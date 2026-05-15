import SwiftUI
import MarkdownUI
import Kingfisher

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
    /// 프로젝트 전체 사진 배열 — 라이트박스 필름스트립 범위로 사용.
    /// 전달하지 않으면 해당 블록 사진만 표시(폴백).
    var allPhotos: [Photo] = []
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var lightboxPhotos: [Photo] = []
    @State private var lightboxIndex: Int = 0
    @State private var showLightbox = false
    @State private var contentWidth: CGFloat = 0

    private var blocks: [PortfolioBlock] { groupPortfolioItems(items) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 컨테이너 폭 측정용
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: 0)
                .background(GeometryReader { geo in
                    Color.clear.onAppear { contentWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, w in contentWidth = w }
                })

            ForEach(blocks) { block in
                if block.isSideBySide {
                    sideBySideBlock(block)
                } else if block.photoItems.isEmpty {
                    if let text = block.textItem?.textContent {
                        Markdown(preprocessMarkdown(text))
                            .font(.custom("Georgia", size: 16))
                    }
                } else {
                    photoBlock(block)
                }
            }
        }
        .fullScreenCover(isPresented: $showLightbox) {
            LightboxView(photos: lightboxPhotos, initialIndex: lightboxIndex, viewModel: nil, projectId: "")
        }
    }

    @ViewBuilder
    private func photoBlock(_ block: PortfolioBlock) -> some View {
        let photos = block.photoItems
        if sizeClass == .regular {
            // iPad: 기존 cols 로직 유지
            if block.blockLayout == "single" || (block.blockLayout == nil && photos.count == 1) {
                singleColumn(photos: photos, block: block)
            } else {
                let cols = block.blockLayout == "wide" ? 2 : 4
                PortfolioJustifiedPhotoGrid(
                    items: photos,
                    cols: cols,
                    gap: 4,
                    containerWidth: contentWidth,
                    onTap: { openLightbox(block: block, index: $0) }
                )
            }
        } else {
            // iPhone: 항상 1열 풀폭 (옵션 A)
            singleColumn(photos: photos, block: block)
        }
    }

    @ViewBuilder
    private func singleColumn(photos: [PortfolioChapterItem], block: PortfolioBlock) -> some View {
        VStack(spacing: 16) {
            ForEach(Array(photos.enumerated()), id: \.offset) { idx, item in
                VStack(alignment: .leading, spacing: 6) {
                    SingleFitPhoto(url: item.imageUrl)
                        .cornerRadius(2)
                        .onTapGesture { openLightbox(block: block, index: idx) }
                    if let cap = item.caption, !cap.isEmpty {
                        Text(cap)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sideBySideBlock(_ block: PortfolioBlock) -> some View {
        let isTextLeft = block.blockType == "side-left"
        if sizeClass == .regular {
            HStack(alignment: .top, spacing: 16) {
                sideParts(block: block, isTextLeft: isTextLeft, isIPad: true)
            }
        } else {
            // iPhone: block_type 의미 보존 — side-left: 텍스트 위, 사진 아래 / side-right: 사진 위, 텍스트 아래
            VStack(alignment: .leading, spacing: 16) {
                if isTextLeft {
                    textCol(block: block)
                    photoColumn(block: block)
                } else {
                    photoColumn(block: block)
                    textCol(block: block)
                }
            }
        }
    }

    @ViewBuilder
    private func sideParts(block: PortfolioBlock, isTextLeft: Bool, isIPad: Bool) -> some View {
        let textColView = textCol(block: block)
        let photoColView = VStack(spacing: 4) {
            ForEach(Array(block.photoItems.enumerated()), id: \.offset) { idx, item in
                CachedImage(url: item.imageUrl, variant: .grid, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(4)
                    .onTapGesture { openLightbox(block: block, index: idx) }
            }
        }
        .frame(maxWidth: .infinity)

        if isTextLeft {
            textColView
            photoColView
        } else {
            photoColView
            textColView
        }
    }

    private func textCol(block: PortfolioBlock) -> some View {
        Markdown(preprocessMarkdown(block.textItem?.textContent ?? ""))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func photoColumn(block: PortfolioBlock) -> some View {
        VStack(spacing: 4) {
            ForEach(Array(block.photoItems.enumerated()), id: \.offset) { idx, item in
                SingleFitPhoto(url: item.imageUrl)
                    .cornerRadius(2)
                    .onTapGesture { openLightbox(block: block, index: idx) }
            }
        }
    }

    private func openLightbox(block: PortfolioBlock, index: Int) {
        let blockPhotos = block.photoItems.compactMap { item -> Photo? in
            guard let url = item.imageUrl else { return nil }
            return Photo(id: item.id ?? UUID().uuidString, projectId: "", imageUrl: url, caption: item.caption, order: 0, localMissing: nil)
        }
        if !allPhotos.isEmpty {
            // 전체 프로젝트 사진 배열 기준으로 필름스트립 구성
            lightboxPhotos = allPhotos
            let tappedUrl = block.photoItems.indices.contains(index) ? block.photoItems[index].imageUrl : nil
            lightboxIndex = allPhotos.firstIndex { $0.imageUrl == tappedUrl } ?? 0
        } else {
            lightboxPhotos = blockPhotos
            lightboxIndex = index
        }
        showLightbox = true
    }
}

// MARK: - Single Layout Photo (ratio-aware, no cropping)

private struct SingleFitPhoto: View {
    let url: String?
    @State private var ratio: CGFloat = 3.0 / 2.0

    var body: some View {
        KFImage(cfUrl(url, variant: .public))
            .placeholder { Color(.secondarySystemBackground) }
            .resizable()
            .onSuccess { result in
                let size = result.image.size
                if size.height > 0 { ratio = size.width / size.height }
            }
            .aspectRatio(ratio, contentMode: .fit)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Portfolio Justified Photo Grid

private struct PortfolioJustifiedPhotoGrid: View {
    let items: [PortfolioChapterItem]
    let cols: Int
    let gap: CGFloat
    let containerWidth: CGFloat
    let onTap: (Int) -> Void     // 전체 items 배열 내 인덱스

    @State private var ratios: [Int: CGFloat] = [:]

    private var rows: [[(index: Int, item: PortfolioChapterItem)]] {
        let indexed = items.enumerated().map { (index: $0.offset, item: $0.element) }
        return stride(from: 0, to: indexed.count, by: cols).map {
            Array(indexed[$0..<min($0 + cols, indexed.count)])
        }
    }

    var body: some View {
        VStack(spacing: gap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                rowView(row)
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: [(index: Int, item: PortfolioChapterItem)]) -> some View {
        let rowRatios = row.map { ratios[$0.index] ?? 1.5 }
        let totalGap = gap * CGFloat(max(0, row.count - 1))
        let rowHeight = containerWidth > 0 ? (containerWidth - totalGap) / rowRatios.reduce(0, +) : 160

        HStack(spacing: gap) {
            ForEach(row.indices, id: \.self) { i in
                let entry = row[i]
                KFImage(cfUrl(entry.item.imageUrl, variant: .grid))
                    .placeholder { Color(.secondarySystemBackground) }
                    .resizable()
                    .onSuccess { result in
                        let size = result.image.size
                        if size.height > 0 {
                            ratios[entry.index] = size.width / size.height
                        }
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: rowHeight * rowRatios[i], height: rowHeight)
                    .clipped()
                    .cornerRadius(2)
                    .onTapGesture { onTap(entry.index) }
            }
        }
        .frame(height: rowHeight)
    }
}
