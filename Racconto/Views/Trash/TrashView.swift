import SwiftUI

struct TrashView: View {
    @State private var viewModel = TrashViewModel()
    @State private var selectedTab = 0
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var lightboxData: LightboxData? = nil

    private var cols: Int { sizeClass == .regular ? 4 : 3 }
    private var gridCols: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 2), count: cols) }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("프로젝트").tag(0)
                Text("사진").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch selectedTab {
                case 0: projectsContent
                default: photosContent
                }
            }
        }
        .navigationTitle("휴지통")
        .task { await viewModel.load() }
        .fullScreenCover(item: $lightboxData) { data in
            LightboxView(
                photos: data.photos,
                initialIndex: data.index,
                viewModel: nil,
                projectId: "",
                onRestore: { photo in Task { await viewModel.restore(photo: photo) } },
                onPermanentDelete: { photo in Task { await viewModel.permanentDelete(photo: photo) } }
            )
        }
    }

    // MARK: - 프로젝트 탭

    @ViewBuilder
    private var projectsContent: some View {
        if viewModel.deletedProjects.isEmpty {
            ContentUnavailableView("삭제된 프로젝트가 없습니다", systemImage: "rectangle.stack")
        } else {
            List {
                ForEach(viewModel.deletedProjects) { project in
                    projectRow(project)
                }
            }
            .listStyle(.plain)
        }
    }

    private func projectRow(_ project: Project) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(.body)
                if let deletedAt = project.deletedAt {
                    Text(deletedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task { await viewModel.permanentDeleteProject(project) }
            } label: {
                Label("영구 삭제", systemImage: "trash.fill")
            }
            Button {
                Task { await viewModel.restoreProject(project) }
            } label: {
                Label("복구", systemImage: "arrow.uturn.backward")
            }
            .tint(.blue)
        }
    }

    // MARK: - 사진 탭

    @ViewBuilder
    private var photosContent: some View {
        if viewModel.photoGroups.isEmpty {
            ContentUnavailableView("삭제된 사진이 없습니다", systemImage: "photo.on.rectangle")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.photoGroups) { group in
                        photoGroupSection(group)
                    }
                }
            }
        }
    }

    private func photoGroupSection(_ group: TrashViewModel.PhotoGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.projectTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 8)

            LazyVGrid(columns: gridCols, spacing: 2) {
                ForEach(group.photos) { photo in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            CachedImage(url: photo.imageUrl, variant: .grid, contentMode: .fill)
                                .clipped()
                        )
                        .clipped()
                        .onTapGesture {
                            let idx = group.photos.firstIndex(where: { $0.id == photo.id }) ?? 0
                            lightboxData = LightboxData(photos: group.photos, index: idx)
                        }
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
                }
            }
            .padding(.bottom, 24)
        }
    }
}
