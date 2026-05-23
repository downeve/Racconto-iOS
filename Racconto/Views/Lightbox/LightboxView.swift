import SwiftUI
import Kingfisher

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
    @State private var showControls = true
    /// 필름스트립 탭으로 인한 인덱스 변경 표시 — onChange에서 무애니메이션 처리
    @State private var filmstripTapInitiated = false

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
    /// viewModel 없고 trash 모드도 아닌 경우 = 포트폴리오 공개 뷰어 모드
    private var isPortfolioMode: Bool { viewModel == nil && onRestore == nil }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 상단 바
                if showControls {
                    if isPortfolioMode {
                        portfolioTopBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        editModeTopBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                // 사진 영역
                TabView(selection: $currentIndex) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { idx, photo in
                        ZoomablePhotoView(url: photo.imageUrl) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showControls.toggle()
                            }
                        }
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // EXIF 패널 (편집 모드 전용)
                if !isPortfolioMode && showControls && showEXIF, let photo = currentPhoto {
                    EXIFPanel(photo: photo)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // 하단 — 포트폴리오: filmstrip / 편집: editBar / 휴지통: trashBar
                if isPortfolioMode {
                    filmstrip
                } else if showControls, let photo = currentPhoto {
                    if isTrashMode {
                        trashBar(photo: photo)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if viewModel != nil {
                        editBar(photo: photo)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showEXIF)
        .animation(.easeInOut(duration: 0.2), value: showControls)
        .onAppear { prefetchNeighbors(of: currentIndex) }
        .onChange(of: currentIndex) { _, new in
            prefetchNeighbors(of: new)
        }
    }

    /// P-2: 현재 사진 기준 ±2장의 public variant를 디스크 캐시에 선프리패치.
    /// TabView는 모든 페이지를 메모리에 두지만 KFImage는 onAppear에 fetch하므로
    /// 스와이프 시 흰 placeholder가 잠깐 보이는 문제 완화.
    private func prefetchNeighbors(of index: Int) {
        let range = max(0, index - 2)...min(photos.count - 1, index + 2)
        guard range.lowerBound <= range.upperBound else { return }
        let urls: [URL] = range.compactMap { i in
            guard i != index, photos.indices.contains(i) else { return nil }
            return URL(string: photos[i].imageUrl)
        }
        guard !urls.isEmpty else { return }
        ImagePrefetcher(urls: urls).start()
    }

    // MARK: - 포트폴리오 상단 바 (캡션 + 공유)

    private var portfolioTopBar: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            if let caption = currentPhoto?.caption, !caption.isEmpty {
                Text(caption)
                    .font(.custom("Georgia-Italic", size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
            }
            Spacer()
            // 우측 ellipsis 메뉴는 미구현 — 좌측 chevron과 균형 위한 invisible spacer 유지.
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    // MARK: - 편집 모드 상단 바 (카운터)

    private var editModeTopBar: some View {
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
    }

    // MARK: - Filmstrip (포트폴리오 뷰어 전용)

    private var filmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(photos.indices, id: \.self) { i in
                        CachedImage(url: photos[i].imageUrl, variant: .grid, contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipped()
                            .opacity(i == currentIndex ? 1.0 : 0.55)
                            .overlay(
                                Rectangle()
                                    .strokeBorder(
                                        Color(red: 0.659, green: 0.263, blue: 0.122),
                                        lineWidth: i == currentIndex ? 2 : 0
                                    )
                            )
                            .id(i)
                            .onTapGesture {
                                // 탭 후 점프는 즉시 처리 — 사용자가 직접 누른 위치이므로
                                // 애니메이션이 어색하게 느껴짐. 스크롤만 자연스럽게 센터로.
                                filmstripTapInitiated = true
                                currentIndex = i
                            }
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 64)
            .onChange(of: currentIndex) { _, new in
                if filmstripTapInitiated {
                    proxy.scrollTo(new, anchor: .center)
                    filmstripTapInitiated = false
                } else {
                    // TabView 스와이프 등 외부 변화: 부드럽게 따라감
                    withAnimation { proxy.scrollTo(new, anchor: .center) }
                }
            }
        }
        .padding(.bottom, 16)
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
                    Task { await viewModel?.rotate(photoId: photo.id, angle: 270) }
                } label: {
                    Image(systemName: "rotate.left")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                Button {
                    Task { await viewModel?.rotate(photoId: photo.id, angle: 90) }
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
                ChapterPickerSheet.invalidateMembershipCache(photoId: photo.id)
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

// MARK: - ZoomablePhotoView

private struct ZoomablePhotoView: View {
    let url: String
    let onSingleTap: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        CachedImage(url: url, variant: .public, contentMode: .fit)
            .scaleEffect(scale)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        scale = max(1.0, lastScale * value.magnification)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale < 1.05 {
                            withAnimation(.spring(duration: 0.3)) { scale = 1.0 }
                            lastScale = 1.0
                        }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(duration: 0.3)) { scale = 1.0 }
                lastScale = 1.0
            }
            .onTapGesture(count: 1) {
                onSingleTap()
            }
    }
}

// MARK: - EXIFPanel

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
