import SwiftUI

struct LightboxView: View {
    @Environment(\.dismiss) private var dismiss
    let photos: [Photo]
    let initialIndex: Int
    var viewModel: PhotosViewModel?
    let projectId: String
    var onRestore: ((Photo) -> Void)? = nil
    var onPermanentDelete: ((Photo) -> Void)? = nil

    @State private var currentIndex: Int
    @State private var showEXIF = false
    @State private var showChapterPicker = false

    init(
        photos: [Photo],
        initialIndex: Int,
        viewModel: PhotosViewModel?,
        projectId: String,
        onRestore: ((Photo) -> Void)? = nil,
        onPermanentDelete: ((Photo) -> Void)? = nil
    ) {
        self.photos = photos
        self.initialIndex = initialIndex
        self.viewModel = viewModel
        self.projectId = projectId
        self.onRestore = onRestore
        self.onPermanentDelete = onPermanentDelete
        _currentIndex = State(initialValue: initialIndex)
    }

    var currentPhoto: Photo? { photos.indices.contains(currentIndex) ? photos[currentIndex] : nil }
    private var isTrashMode: Bool { onRestore != nil }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 상단 바
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("\(currentIndex + 1) / \(photos.count)")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

                // 사진 영역 — 하단 바 위까지만 차지
                TabView(selection: $currentIndex) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { idx, photo in
                        CachedImage(url: photo.imageUrl, variant: .public, contentMode: .fit)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // EXIF 패널
                if showEXIF, let photo = currentPhoto {
                    EXIFPanel(photo: photo)
                        .transition(.move(edge: .bottom))
                }

                // 하단 바
                if let photo = currentPhoto {
                    if isTrashMode {
                        trashBar(photo: photo)
                    } else if viewModel != nil {
                        editBar(photo: photo)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showEXIF)
    }

    // MARK: - 일반 편집 바

    private func editBar(photo: Photo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { n in
                    Button {
                        Task { await viewModel?.updateRating(photoId: photo.id, rating: n) }
                    } label: {
                        Image(systemName: n <= (photo.rating ?? 0) ? "star.fill" : "star")
                            .foregroundStyle(n <= (photo.rating ?? 0) ? .yellow : .white)
                    }
                }
                Spacer()
            }
            HStack(spacing: 16) {
                ForEach(["red", "yellow", "green", "blue", "purple"], id: \.self) { label in
                    colorLabelButton(photo: photo, label: label)
                }
                Spacer()
                Button { showChapterPicker = true } label: {
                    Image(systemName: "text.badge.plus")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                Button {
                    Task { await viewModel?.rotate(photoId: photo.id, direction: "left") }
                } label: {
                    Image(systemName: "rotate.left")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                Button {
                    Task { await viewModel?.rotate(photoId: photo.id, direction: "right") }
                } label: {
                    Image(systemName: "rotate.right")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                Button {
                    withAnimation { showEXIF.toggle() }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(showEXIF ? .yellow : .white)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showChapterPicker) {
            ChapterPickerSheet(projectId: projectId, onSelect: { chapter, alreadyIn in
                Task {
                    if alreadyIn.contains(chapter.id) {
                        await viewModel?.removeFromChapter(photoId: photo.id, chapterId: chapter.id)
                    } else {
                        for oldChapterId in alreadyIn {
                            await viewModel?.removeFromChapter(photoId: photo.id, chapterId: oldChapterId)
                        }
                        await viewModel?.addToChapter(photoIds: [photo.id], chapterId: chapter.id)
                    }
                }
            }, photoId: photo.id)
        }
    }

    // MARK: - 휴지통 바

    private func trashBar(photo: Photo) -> some View {
        HStack(spacing: 0) {
            Button {
                onRestore?(photo)
                dismiss()
            } label: {
                Label("복구", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .foregroundStyle(.white)

            Divider().frame(height: 24).background(.white.opacity(0.3))

            Button {
                onPermanentDelete?(photo)
                dismiss()
            } label: {
                Label("영구 삭제", systemImage: "trash.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial)
    }

    private func colorLabelButton(photo: Photo, label: String) -> some View {
        let colorMap: [String: Color] = [
            "red": .red, "yellow": .yellow, "green": .green, "blue": .blue, "purple": .purple
        ]
        return Button {
            Task { await viewModel?.updateColorLabel(photoId: photo.id, label: photo.colorLabel == label ? nil : label) }
        } label: {
            Circle()
                .fill(colorMap[label] ?? .gray)
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.white, lineWidth: photo.colorLabel == label ? 2 : 0).padding(-2))
        }
    }
}

struct EXIFPanel: View {
    let photo: Photo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let camera = photo.camera { exifRow("camera", camera) }
            if let lens = photo.lens { exifRow("camera.aperture", lens) }
            HStack(spacing: 16) {
                if let iso = photo.iso { Text(iso).font(.caption).foregroundStyle(.white) }
                if let ss = photo.shutterSpeed { Text(ss).font(.caption).foregroundStyle(.white) }
                if let ap = photo.aperture { Text(ap).font(.caption).foregroundStyle(.white) }
                if let fl = photo.focalLength { Text(fl).font(.caption).foregroundStyle(.white) }
            }
            if let lat = photo.gpsLat, let lng = photo.gpsLng {
                exifRow("mappin", "\(lat), \(lng)")
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private func exifRow(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon).font(.caption).foregroundStyle(.white)
    }
}
