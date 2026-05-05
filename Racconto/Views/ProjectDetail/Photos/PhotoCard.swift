import SwiftUI

struct PhotoCard: View {
    let photo: Photo
    let isSelecting: Bool
    let isSelected: Bool
    let projectId: String
    var viewModel: PhotosViewModel
    let onLightbox: () -> Void
    let onAddToChapter: () -> Void

    private let colorLabels = ["red", "orange", "yellow", "green", "blue"]
    private let colorMap: [String: Color] = [
        "red": .red, "orange": .orange, "yellow": .yellow, "green": .green, "blue": .blue
    ]

    var body: some View {
        Color.gray.opacity(0.08)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                CachedImage(url: photo.imageUrl, variant: .grid, contentMode: .fill)
            }
            .overlay(alignment: .topTrailing) {
                if let label = photo.colorLabel, let color = colorMap[label] {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .padding(4)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let rating = photo.rating, rating > 0 {
                    HStack(spacing: 1) {
                        ForEach(1...rating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.yellow)
                        }
                    }
                    .padding(4)
                }
            }
            .overlay {
                if isSelecting {
                    Color.black.opacity(isSelected ? 0.4 : 0)
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isSelected ? .white : Color.white.opacity(0.8))
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .contextMenu {
                if !isSelecting {
                    Menu("별점") {
                        ForEach(1...5, id: \.self) { n in
                            Button {
                                Task { await viewModel.updateRating(photoId: photo.id, rating: n) }
                            } label: {
                                Label(String(repeating: "★", count: n), systemImage: photo.rating == n ? "checkmark" : "")
                            }
                        }
                        if photo.rating != nil {
                            Button("별점 제거", role: .destructive) {
                                Task { await viewModel.updateRating(photoId: photo.id, rating: 0) }
                            }
                        }
                    }
                    Menu("컬러 라벨") {
                        ForEach(colorLabels, id: \.self) { label in
                            Button {
                                Task { await viewModel.updateColorLabel(photoId: photo.id, label: photo.colorLabel == label ? nil : label) }
                            } label: {
                                Label(label.capitalized, systemImage: photo.colorLabel == label ? "checkmark" : "")
                            }
                        }
                    }
                    Button {
                        Task { await viewModel.setCoverImage(projectId: projectId, imageUrl: photo.imageUrl) }
                    } label: {
                        Label("커버로 지정", systemImage: "photo")
                    }
                    Button { onAddToChapter() } label: {
                        Label("챕터에 추가", systemImage: "text.badge.plus")
                    }
                    Button { onLightbox() } label: {
                        Label("크게 보기", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    Divider()
                    Button(role: .destructive) {
                        Task { await viewModel.softDelete(photoId: photo.id) }
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
    }
}
