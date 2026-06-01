import SwiftUI
import MarkdownUI
import Kingfisher

struct StoryPreviewView: View {
    var viewModel: StoryViewModel
    let projectId: String
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var lightboxData: LightboxData? = nil
    @State private var contentWidth: CGFloat = 0

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                // 컨테이너 폭 측정용 (높이 0, 레이아웃 영향 없음)
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: 0)
                    .background(GeometryReader { geo in
                        Color.clear.onAppear { contentWidth = geo.size.width }
                            .onChange(of: geo.size.width) { _, w in contentWidth = w }
                    })

                ForEach(Array(viewModel.chapterTree.enumerated()), id: \.element.parent.id) { idx, node in
                    chapterSection(node, chapterIndex: idx + 1)
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .fullScreenCover(item: $lightboxData) { data in
            LightboxView(photos: data.photos, initialIndex: data.index, viewModel: nil, projectId: projectId)
        }
    }

    @ViewBuilder
    private func chapterSection(_ node: ChapterNode, chapterIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("챕터 \(chapterIndex)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(node.parent.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                if let desc = node.parent.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(viewModel.blocks(for: node.parent.id)) { block in
                blockView(block, allPhotosInChapter: photosIn(chapterId: node.parent.id))
            }

            ForEach(Array(node.subs.enumerated()), id: \.element.id) { subIdx, sub in
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("챕터 \(chapterIndex).\(subIdx + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(sub.title)
                            .font(.title3)
                            .fontWeight(.medium)
                        if let desc = sub.description, !desc.isEmpty {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(viewModel.blocks(for: sub.id)) { block in
                        blockView(block, allPhotosInChapter: photosIn(chapterId: sub.id))
                    }
                }
                .padding(.leading, 8)
            }
        }

        Divider()
    }

    @ViewBuilder
    private func blockView(_ block: Block, allPhotosInChapter: [Photo]) -> some View {
        // SIDE 블록인데 사진이 모두 휴지통/삭제되어 텍스트만 남은 경우 → 단독 TEXT 블록처럼 렌더.
        // 웹 PortfolioChapterItems / MobilePortfolioChapterItems 동일 폴백.
        if block.isSideBySide && !block.photoItems.isEmpty {
            sideBySideView(block, allPhotos: allPhotosInChapter)
        } else if block.photoItems.isEmpty {
            if let text = block.textItem?.textContent {
                Text(MarkdownInline.attributed(text))
                    .font(.custom("Georgia", size: 16))
            }
        } else {
            photoBlockView(block, allPhotos: allPhotosInChapter)
        }
    }

    @ViewBuilder
    private func photoBlockView(_ block: Block, allPhotos: [Photo]) -> some View {
        let photos = block.photoItems
        // iPhone: 웹 MobilePortfolioChapterItems와 동일하게 GRID/WIDE/SINGLE 모두 1열 풀폭.
        // iPad: blockLayout에 따라 single 풀폭 또는 JustifiedPhotoGrid.
        if sizeClass != .regular || block.blockLayout == .single {
            VStack(spacing: 4) {
                ForEach(photos) { item in
                    // 풀너비 사진 — iPhone lightboxmobile(1600) / iPad lightbox(2048)
                    // 사진 모서리 0pt (웹 rounded-photo, 각진 프린트 무드)
                    CachedImage(url: item.imageUrl, variant: lightboxVariant(for: sizeClass), contentMode: .fit)
                        .cornerRadius(Radius.photo)
                        .onTapGesture { openLightbox(for: item, allPhotos: allPhotos) }
                }
            }
        } else {
            // 웹 PortfolioChapterItems와 동일: wide 2열 / grid 3열
            let cols = block.blockLayout == .wide ? 2 : 3
            JustifiedPhotoGrid(
                items: photos,
                cols: cols,
                gap: 4,
                containerWidth: contentWidth,
                onTap: { openLightbox(for: $0, allPhotos: allPhotos) }
            )
        }
    }

    @ViewBuilder
    private func sideBySideView(_ block: Block, allPhotos: [Photo]) -> some View {
        let isTextLeft = block.blockType == "side-left"
        if sizeClass == .regular {
            // iPad: 웹 PortfolioChapterItems 정책 — 사진 3 : 텍스트 2, portrait cap 적용.
            SideBySideRow(
                block: block,
                isTextLeft: isTextLeft,
                containerWidth: contentWidth,
                onTap: { openLightbox(for: $0, allPhotos: allPhotos) }
            )
        } else {
            // iPhone: 1열 vstack (사진 자연 비율). 기존 모바일 정책 유지.
            VStack(alignment: .leading, spacing: 12) {
                sidePartsMobile(block: block, isTextLeft: isTextLeft, allPhotos: allPhotos)
            }
        }
    }

    @ViewBuilder
    private func sidePartsMobile(block: Block, isTextLeft: Bool, allPhotos: [Photo]) -> some View {
        let photos = block.photoItems
        let text = block.textItem?.textContent ?? ""
        let photoCol = Group {
            ForEach(photos) { item in
                CachedImage(url: item.imageUrl, variant: .grid, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(Radius.photo)
                    .onTapGesture { openLightbox(for: item, allPhotos: allPhotos) }
            }
        }
        let textCol = Text(MarkdownInline.attributed(text))
            .frame(maxWidth: .infinity, alignment: .leading)

        if isTextLeft {
            VStack { textCol }
            VStack { photoCol }
        } else {
            VStack { photoCol }
            VStack { textCol }
        }
    }

    private func photosIn(chapterId: String) -> [Photo] {
        viewModel.itemsByChapter[chapterId]?
            .filter { $0.itemType == .photo }
            .compactMap { item -> Photo? in
                guard let url = item.imageUrl else { return nil }
                return Photo(
                    id: item.photoId ?? item.id,
                    projectId: "",
                    imageUrl: url,
                    caption: item.caption,
                    order: item.orderNum,
                    localMissing: nil
                )
            } ?? []
    }

    private func openLightbox(for item: ChapterItem, allPhotos: [Photo]) {
        let idx = allPhotos.firstIndex(where: { $0.id == (item.photoId ?? item.id) }) ?? 0
        lightboxData = LightboxData(photos: allPhotos, index: idx)
    }
}

// MARK: - Justified Photo Grid

private struct JustifiedPhotoGrid: View {
    let items: [ChapterItem]
    let cols: Int
    let gap: CGFloat
    let containerWidth: CGFloat
    let onTap: (ChapterItem) -> Void

    @State private var ratios: [String: CGFloat] = [:]

    private var rows: [[ChapterItem]] {
        guard !items.isEmpty else { return [] }
        return stride(from: 0, to: items.count, by: cols).map {
            Array(items[$0..<min($0 + cols, items.count)])
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
    private func rowView(_ row: [ChapterItem]) -> some View {
        let rowRatios = row.map { ratios[$0.id] ?? 1.5 }
        let totalGap = gap * CGFloat(max(0, row.count - 1))
        let sumRatios = rowRatios.reduce(0, +)
        let rowHeight = containerWidth > 0 ? (containerWidth - totalGap) / sumRatios : 160

        HStack(spacing: gap) {
            ForEach(Array(zip(row, rowRatios)), id: \.0.id) { item, ratio in
                KFImage(cfUrl(item.imageUrl, variant: .grid))
                    .placeholder { Color(.secondarySystemBackground) }
                    .resizable()
                    .onSuccess { result in
                        let size = result.image.size
                        if size.height > 0 {
                            ratios[item.id] = size.width / size.height
                        }
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: rowHeight * ratio, height: rowHeight)
                    .clipped()
                    .cornerRadius(Radius.photo)
                    .onTapGesture { onTap(item) }
            }
        }
        .frame(height: rowHeight)
    }
}

// MARK: - Side-by-side Row (iPad)
//
// 웹 PortfolioChapterItems의 SIDE 블록 정책:
// - 사진 3 : 텍스트 2 (flex 비율, gap 24~28 사이 자동)
// - 사진의 ratio < 1 이고 1/ratio > 1.33 (portrait 강함)이면 maxHeight = photoColWidth × 1.33 캡
// - 캡 적용 시 텍스트와 마주보는 안쪽 가장자리로 정렬

private struct SideBySideRow: View {
    let block: Block
    let isTextLeft: Bool
    let containerWidth: CGFloat
    let onTap: (ChapterItem) -> Void

    /// KFImage.onSuccess로 측정한 사진 ratio (width/height).
    @State private var ratios: [String: CGFloat] = [:]

    private var photos: [ChapterItem] { block.photoItems }
    private var text: String { block.textItem?.textContent ?? "" }
    private var isPhotoRight: Bool { block.blockType == "side-right" }

    /// portrait cap이 하나라도 발생하는지 — 발생 시 gap 24, 아니면 28.
    private var hasCappedPortrait: Bool {
        photos.contains { item in
            guard let r = ratios[item.id] else { return false }
            return r < 1 && (1 / r) > 1.33
        }
    }

    private var sideGap: CGFloat { hasCappedPortrait ? 24 : 28 }
    private var photoColWidth: CGFloat { max(0, (containerWidth - sideGap) * 3 / 5) }
    private var textColWidth:  CGFloat { max(0, (containerWidth - sideGap) * 2 / 5) }

    var body: some View {
        HStack(alignment: .top, spacing: sideGap) {
            if isPhotoRight {
                textCol
                photoCol
            } else {
                photoCol
                textCol
            }
        }
    }

    private var photoCol: some View {
        VStack(spacing: 8) {
            ForEach(photos) { item in
                photoView(item)
            }
        }
        .frame(width: photoColWidth, alignment: .top)
    }

    @ViewBuilder
    private func photoView(_ item: ChapterItem) -> some View {
        let ratio = ratios[item.id] ?? 1.5
        let isPortraitCapped = ratio < 1 && (1 / ratio) > 1.33
        let renderedWidth: CGFloat
        let renderedHeight: CGFloat
        if isPortraitCapped {
            // maxHeight = colW × 1.33 — 세로로 너무 긴 사진을 캡.
            renderedHeight = photoColWidth * 1.33
            renderedWidth = renderedHeight * ratio
        } else {
            renderedWidth = photoColWidth
            renderedHeight = photoColWidth / ratio
        }

        // 캡 적용 시 텍스트와 마주보는 안쪽 가장자리(사진 오른쪽이면 left, 왼쪽이면 right) 정렬.
        let alignment: Alignment = {
            guard isPortraitCapped else { return .center }
            return isPhotoRight ? .leading : .trailing
        }()

        return Color.clear
            .frame(width: photoColWidth, height: renderedHeight)
            .overlay(alignment: alignment) {
                KFImage(cfUrl(item.imageUrl, variant: .public))
                    .placeholder { Color(.secondarySystemBackground) }
                    .resizable()
                    .onSuccess { result in
                        let size = result.image.size
                        if size.height > 0 {
                            ratios[item.id] = size.width / size.height
                        }
                    }
                    .aspectRatio(contentMode: .fit)
                    .frame(width: renderedWidth, height: renderedHeight)
                    .cornerRadius(Radius.photo)
                    .onTapGesture { onTap(item) }
            }
    }

    private var textCol: some View {
        Text(MarkdownInline.attributed(text))
            .frame(width: textColWidth, alignment: .leading)
    }
}
