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
        if block.isSideBySide {
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
                    CachedImage(url: item.imageUrl, variant: lightboxVariant(for: sizeClass), contentMode: .fit)
                        .cornerRadius(Radius.btn)
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
            HStack(alignment: .top, spacing: 16) {
                sideParts(block: block, isTextLeft: isTextLeft, allPhotos: allPhotos)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                sideParts(block: block, isTextLeft: isTextLeft, allPhotos: allPhotos)
            }
        }
    }

    @ViewBuilder
    private func sideParts(block: Block, isTextLeft: Bool, allPhotos: [Photo]) -> some View {
        let photos = block.photoItems
        let text = block.textItem?.textContent ?? ""
        let photoCol = Group {
            ForEach(photos) { item in
                CachedImage(url: item.imageUrl, variant: .grid, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(Radius.cell)
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
                    .cornerRadius(Radius.btn)
                    .onTapGesture { onTap(item) }
            }
        }
        .frame(height: rowHeight)
    }
}
