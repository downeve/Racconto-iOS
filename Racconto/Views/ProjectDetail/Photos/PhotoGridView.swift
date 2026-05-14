import SwiftUI

struct PhotoGridView: View {
    let photos: [Photo]
    var viewModel: PhotosViewModel
    let project: Project
    let onLightbox: ([Photo], Int) -> Void
    let onAddToChapter: ([String]) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var startColumns = 0
    @State private var isGesturing = false

    private var minColumns: Int { 1 }
    private var maxColumns: Int { sizeClass == .regular ? 8 : 6 }

    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: viewModel.columns)
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
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    if !isGesturing {
                        startColumns = viewModel.columns
                        isGesturing = true
                    }
                    let newCols = Int((Double(startColumns) / Double(value)).rounded())
                    viewModel.columns = min(maxColumns, max(minColumns, newCols))
                }
                .onEnded { _ in
                    isGesturing = false
                }
        )
    }
}
