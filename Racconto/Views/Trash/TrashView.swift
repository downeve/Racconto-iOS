import SwiftUI

struct TrashView: View {
    @State private var viewModel = TrashViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var lightboxData: LightboxData? = nil

    private var cols: Int { sizeClass == .regular ? 4 : 2 }
    private var gridCols: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 2), count: cols) }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.photos.isEmpty {
                ContentUnavailableView("휴지통이 비어 있습니다", systemImage: "trash")
            } else {
                photoGrid
            }
        }
        .navigationTitle("휴지통")
        .task { await viewModel.load() }
        .fullScreenCover(item: $lightboxData) { data in
            LightboxView(photos: data.photos, initialIndex: data.index, viewModel: nil, projectId: "")
        }
    }

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridCols, spacing: 2) {
                ForEach(viewModel.photos) { photo in
                    CachedImage(url: photo.imageUrl, variant: .grid, contentMode: .fill)
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                        .contextMenu {
                            Button {
                                Task { await viewModel.restore(photo: photo) }
                            } label: {
                                Label("복구", systemImage: "arrow.uturn.backward")
                            }
                            Button(role: .destructive) {
                                Task { await viewModel.permanentDelete(photo: photo) }
                            } label: {
                                Label("영구 삭제", systemImage: "trash.fill")
                            }
                        }
                        .onTapGesture {
                            let photos = viewModel.photos
                            let idx = photos.firstIndex(where: { $0.id == photo.id }) ?? 0
                            lightboxData = LightboxData(photos: photos, index: idx)
                        }
                }
            }
        }
    }
}
