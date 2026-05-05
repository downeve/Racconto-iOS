import SwiftUI

struct LightboxData: Identifiable {
    let id = UUID()
    let photos: [Photo]
    let index: Int
}

struct PhotosTabView: View {
    let project: Project
    var viewModel: PhotosViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var showPicker = false
    @State private var lightboxData: LightboxData? = nil
    @State private var showChapterPicker = false
    @State private var chapterPickerPhotoIds: [String] = []

    private var defaultColumns: Int { sizeClass == .regular ? 4 : 2 }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                filterBar

                if viewModel.isLoading && viewModel.photos.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.photos.isEmpty {
                    Spacer()
                    ContentUnavailableView("사진이 없습니다", systemImage: "photo.on.rectangle")
                    Spacer()
                } else {
                    PhotoGridView(
                        photos: viewModel.filteredPhotos,
                        columns: viewModel.columns,
                        viewModel: viewModel,
                        project: project,
                        onLightbox: { photos, idx in lightboxData = LightboxData(photos: photos, index: idx) },
                        onAddToChapter: { ids in
                            chapterPickerPhotoIds = ids
                            showChapterPicker = true
                        }
                    )
                }

                if UploadService.shared.pendingCount > 0 || UploadService.shared.isUploading || UploadService.shared.hasFailedItems {
                    UploadProgressView(
                        pendingCount: UploadService.shared.pendingCount,
                        isUploading: UploadService.shared.isUploading,
                        hasFailed: UploadService.shared.hasFailedItems
                    )
                }

                if viewModel.isSelecting {
                    selectionBar
                }
            }

            if !viewModel.isSelecting {
                Button { showPicker = true } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.medium)
                        .frame(width: 52, height: 52)
                        .background(Color.primary)
                        .foregroundStyle(Color(UIColor.systemBackground))
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(viewModel.isSelecting ? "완료" : "선택") {
                    viewModel.isSelecting.toggle()
                    if !viewModel.isSelecting { viewModel.clearSelection() }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    let range = sizeClass == .regular ? [3, 4, 5] : [1, 2, 3]
                    ForEach(range, id: \.self) { n in
                        Button("\(n)열") { viewModel.columns = n }
                    }
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .symbolVariant(viewModel.columns == defaultColumns ? .none : .fill)
                }
            }
        }
        .fullScreenCover(item: $lightboxData) { data in
            LightboxView(photos: data.photos, initialIndex: data.index, viewModel: viewModel, projectId: project.id)
        }
        .sheet(isPresented: $showPicker) {
            PhotoPicker { items in
                for (image, data, filename) in items {
                    let exif = EXIFExtractor.extract(from: data)
                    UploadService.shared.enqueue(
                        image: image,
                        exif: exif,
                        projectId: project.id,
                        filename: filename
                    )
                }
            }
        }
        .sheet(isPresented: $showChapterPicker) {
            ChapterPickerSheet(projectId: project.id) { chapter in
                Task { await viewModel.addToChapter(photoIds: chapterPickerPhotoIds, chapterId: chapter.id) }
            }
        }
        .onAppear { if viewModel.columns == 2 { viewModel.columns = defaultColumns } }
        .onChange(of: UploadService.shared.completedCount) { _, _ in
            Task { await viewModel.load(projectId: project.id) }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "전체", isActive: viewModel.ratingFilter == nil && viewModel.colorFilter == nil) {
                    viewModel.ratingFilter = nil
                    viewModel.colorFilter = nil
                }
                ForEach(1...5, id: \.self) { n in
                    FilterChip(label: String(repeating: "★", count: n), isActive: viewModel.ratingFilter == n) {
                        viewModel.ratingFilter = viewModel.ratingFilter == n ? nil : n
                    }
                }
                ForEach(["red", "orange", "yellow", "green", "blue"], id: \.self) { label in
                    ColorFilterChip(label: label, isActive: viewModel.colorFilter == label) {
                        viewModel.colorFilter = viewModel.colorFilter == label ? nil : label
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private var selectionBar: some View {
        HStack {
            Button {
                chapterPickerPhotoIds = Array(viewModel.selectedIds)
                showChapterPicker = true
            } label: {
                Label("챕터 추가", systemImage: "text.badge.plus")
            }
            .disabled(viewModel.selectedIds.isEmpty)

            Spacer()

            Button(role: .destructive) {
                let ids = Array(viewModel.selectedIds)
                viewModel.clearSelection()
                for id in ids {
                    Task { await viewModel.softDelete(photoId: id) }
                }
            } label: {
                Label("삭제", systemImage: "trash")
            }
            .disabled(viewModel.selectedIds.isEmpty)

            Spacer()

            Button("취소") { viewModel.clearSelection() }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isActive ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isActive ? Color.primary : Color(.secondarySystemBackground))
                .foregroundStyle(isActive ? Color(UIColor.systemBackground) : .primary)
                .clipShape(Capsule())
        }
    }
}

struct ColorFilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void
    private let colorMap: [String: Color] = [
        "red": .red, "orange": .orange, "yellow": .yellow, "green": .green, "blue": .blue
    ]

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(colorMap[label] ?? .gray)
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.primary, lineWidth: isActive ? 2 : 0).padding(-2))
        }
    }
}
