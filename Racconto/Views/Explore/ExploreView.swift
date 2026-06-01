import SwiftUI

/// 탐색 화면 — 웹 Explore.tsx(iPad) + MobileExplore.tsx(iPhone) 기반.
/// 정렬: 가장 최근 공개 시점 내림차순.
/// 필터: 카메라 종류(film/digital/mobile/mixed).
/// 검색: 사진가 username prefix + 포트폴리오 제목/태그 — debounce 300ms.
struct ExploreView: View {
    @State private var viewModel = ExploreViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.colorScheme) private var colorScheme

    /// 진입 username을 외부에서 받고, 카드 탭 시 set → NavigationLink로 PublicPortfolioView 진입.
    @State private var selectedUsername: String? = nil

    // PART D-1: Asset Catalog rcCanvas — Light/Dark Appearance 자동 전환.
    private var portfolioBg: Color { .rcCanvas }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                banner
                    .padding(.bottom, 24)

                searchField
                    .padding(.bottom, 16)

                if !viewModel.isSearching {
                    cameraChips
                        .padding(.bottom, sizeClass == .regular ? 48 : 32)
                }

                if viewModel.isSearching {
                    searchResultsSection
                } else {
                    feedSection
                }

                // 무한 스크롤 sentinel — onAppear 시 다음 페이지 fetch
                if !viewModel.isSearching && viewModel.hasMore && !viewModel.items.isEmpty {
                    Color.clear
                        .frame(height: 1)
                        .onAppear { Task { await viewModel.loadMoreIfNeeded() } }
                }
            }
            .padding(.horizontal, sizeClass == .regular ? 32 : 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: sizeClass == .regular ? 960 : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(portfolioBg)
        .navigationTitle("탐색")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.items.isEmpty {
                await viewModel.resetAndLoad(filter: nil)
            }
        }
        .navigationDestination(item: $selectedUsername) { username in
            PublicPortfolioView(presetUsername: username)
        }
    }

    // MARK: - Banner

    private var banner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DISCOVER")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(.secondary)
            Text("Photographers")
                .font(.custom("Georgia", size: sizeClass == .regular ? 44 : 32))
                .fontWeight(.regular)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
            TextField("사진가 또는 포트폴리오 검색", text: $viewModel.searchInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: viewModel.searchInput) { _, _ in
                    viewModel.onSearchInputChanged()
                }
            if !viewModel.searchInput.isEmpty {
                Button { viewModel.clearSearch() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Radius.btn)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .frame(maxWidth: sizeClass == .regular ? 360 : .infinity, alignment: .leading)
    }

    // MARK: - Camera Chips

    private var cameraChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "전체", active: viewModel.cameraFilter == nil) {
                    Task { await viewModel.resetAndLoad(filter: nil) }
                }
                ForEach(CameraType.allCases, id: \.self) { ct in
                    chip(label: ct.label, active: viewModel.cameraFilter == ct) {
                        Task { await viewModel.resetAndLoad(filter: ct) }
                    }
                }
            }
            .padding(.horizontal, 1) // 칩 stroke 잘림 방지
        }
    }

    private func chip(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: active ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(active ? Color.primary : Color.clear)
                .foregroundStyle(active ? Color(UIColor.systemBackground) : Color.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.btn)
                        .stroke(active ? Color.primary : Color(.separator), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResultsSection: some View {
        if viewModel.searchLoading && viewModel.searchResults == nil {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if let results = viewModel.searchResults {
            if results.users.isEmpty && results.portfolios.isEmpty {
                Text("검색 결과가 없습니다.")
                    .font(.custom("Georgia", size: 20))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 48)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 40) {
                    if !results.users.isEmpty {
                        usersSection(results.users)
                    }
                    if !results.portfolios.isEmpty {
                        portfoliosSection(results.portfolios)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func usersSection(_ users: [ExploreSearchUser]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PHOTOGRAPHERS")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.tertiary)
            // iPhone 3열, iPad 4~5열
            let cols = sizeClass == .regular ? 5 : 3
            let gridCols = Array(repeating: GridItem(.flexible(), spacing: 12), count: cols)
            LazyVGrid(columns: gridCols, spacing: 24) {
                ForEach(users) { u in
                    Button { selectedUsername = u.username } label: {
                        userCell(u)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func userCell(_ user: ExploreSearchUser) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let url = user.coverImageUrl {
                        CachedImage(url: url, variant: .grid, contentMode: .fill)
                    } else {
                        Color(.secondarySystemBackground)
                    }
                }
                .clipped()
            Text("@\(user.username)")
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func portfoliosSection(_ portfolios: [ExploreItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PORTFOLIOS")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.tertiary)
            portfolioList(portfolios)
        }
    }

    // MARK: - Feed

    @ViewBuilder
    private var feedSection: some View {
        if viewModel.items.isEmpty && !viewModel.isLoading {
            Text("아직 포트폴리오가 없습니다.\n첫 사진가가 되어 스토리를 공유해 보세요.")
                .font(.custom("Georgia", size: 22))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .padding(.vertical, 80)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            portfolioList(viewModel.items)
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
    }

    // MARK: - Shared portfolio list (iPhone 1열, iPad 2~3열)

    @ViewBuilder
    private func portfolioList(_ items: [ExploreItem]) -> some View {
        if sizeClass == .regular {
            // iPad: GeometryReader로 폭에 따라 2~3열
            GeometryReader { geo in
                let cols = geo.size.width > 800 ? 3 : 2
                let gridCols = Array(repeating: GridItem(.flexible(), spacing: 28), count: cols)
                LazyVGrid(columns: gridCols, spacing: 60) {
                    ForEach(items) { item in
                        Button { tap(item: item) } label: {
                            ExplorePortfolioCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            // GeometryReader는 자식 크기를 못 잡으므로 row 수에 따라 높이 추정 (대략 카드 600pt × 행수 / cols)
            .frame(minHeight: CGFloat((items.count + 1) / 2) * 540)
        } else {
            // iPhone: 1열, 카드 사이 여백 48
            LazyVStack(alignment: .leading, spacing: 48) {
                ForEach(items) { item in
                    Button { tap(item: item) } label: {
                        ExplorePortfolioCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func tap(item: ExploreItem) {
        guard let username = item.author.username else { return }
        // 슬러그 단위 진입은 후속 — 현재는 사용자 포트폴리오 홈으로
        selectedUsername = username
    }
}

// MARK: - Portfolio Card

/// 웹 PortfolioListCard(mode="explore") 대응 — cover + camera/tags eyebrow + title + author
private struct ExplorePortfolioCard: View {
    let item: ExploreItem

    /// 카메라 타입(있으면) + 모든 태그를 ` · ` 구분자로 단일 Text. lineLimit(1)이 적용 가능하도록
    /// HStack 대신 String join 방식.
    private var eyebrowText: Text {
        var parts: [String] = []
        if let ct = item.cameraType {
            parts.append(ct.label)
        }
        parts.append(contentsOf: item.tags.map { "#\($0)" })
        return Text(parts.joined(separator: " · "))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Color.clear
                .aspectRatio(3.0 / 2.0, contentMode: .fit)
                .overlay {
                    if let url = item.coverImageUrl {
                        CachedImage(url: url, variant: .grid, contentMode: .fill)
                    } else {
                        Color(.secondarySystemBackground)
                    }
                }
                .clipped()

            // eyebrow: 카메라 종류 · 태그 (한 줄, 길면 truncate)
            if item.cameraType != nil || !item.tags.isEmpty {
                eyebrowText
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(item.title)
                .font(.custom("Georgia", size: 22))
                .fontWeight(.regular)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if let username = item.author.username {
                Text("@\(username)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
