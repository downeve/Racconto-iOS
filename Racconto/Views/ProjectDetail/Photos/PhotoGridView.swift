import SwiftUI

struct PhotoGridView: View {
    let photos: [Photo]
    let columns: Int
    var viewModel: PhotosViewModel
    let project: Project
    let onLightbox: ([Photo], Int) -> Void
    let onAddToChapter: ([String]) -> Void

    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: columns)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 2) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { idx, photo in
                    PhotoCard(
                        photo: photo,
                        isSelecting: viewModel.isSelecting,
                        isSelected: viewModel.selectedIds.contains(photo.id),
                        projectId: project.id,
                        viewModel: viewModel,
                        onLightbox: { onLightbox(photos, idx) },
                        onAddToChapter: { onAddToChapter([photo.id]) }
                    )
                    .onTapGesture {
                        if viewModel.isSelecting {
                            viewModel.toggleSelection(photo.id)
                        } else {
                            onLightbox(photos, idx)
                        }
                    }
                }
            }
            .padding(.bottom, 80)
        }
    }
}
