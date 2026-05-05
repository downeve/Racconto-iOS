import SwiftUI
import MarkdownUI

struct StoryPreviewView: View {
    var viewModel: StoryViewModel
    let projectId: String
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var lightboxData: LightboxData? = nil

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                ForEach(viewModel.chapterTree, id: \.parent.id) { node in
                    chapterSection(node)
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
    private func chapterSection(_ node: ChapterNode) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // 최상위 챕터 헤더
            VStack(alignment: .leading, spacing: 4) {
                Text(node.parent.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                if let desc = node.parent.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // 최상위 챕터 블록
            ForEach(viewModel.blocks(for: node.parent.id)) { block in
                blockView(block, allPhotosInChapter: photosIn(chapterId: node.parent.id))
            }

            // 서브챕터
            ForEach(node.subs) { sub in
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
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
                Markdown(text)
                    .font(.custom("Georgia", size: 16))
            }
        } else {
            photoBlockView(block, allPhotos: allPhotosInChapter)
        }
    }

    @ViewBuilder
    private func photoBlockView(_ block: Block, allPhotos: [Photo]) -> some View {
        let cols: Int = {
            switch block.blockLayout {
            case .grid: return sizeClass == .regular ? 4 : 3
            case .wide: return 2
            case .single: return 1
            }
        }()
        let gridCols = Array(repeating: GridItem(.flexible(), spacing: 4), count: cols)

        LazyVGrid(columns: gridCols, spacing: 4) {
            ForEach(block.photoItems) { item in
                CachedImage(url: item.imageUrl, variant: .grid, contentMode: .fill)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .cornerRadius(2)
                    .onTapGesture {
                        openLightbox(for: item, allPhotos: allPhotos)
                    }
            }
        }
    }

    @ViewBuilder
    private func sideBySideView(_ block: Block, allPhotos: [Photo]) -> some View {
        let isTextLeft = block.blockType == "side-left"
        Group {
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
                    .cornerRadius(4)
                    .onTapGesture { openLightbox(for: item, allPhotos: allPhotos) }
            }
        }
        let textCol = Markdown(text).frame(maxWidth: .infinity, alignment: .leading)

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
        let photos = allPhotos
        let idx = allPhotos.firstIndex(where: { $0.id == (item.photoId ?? item.id) }) ?? 0
        lightboxData = LightboxData(photos: photos, index: idx)
    }
}
