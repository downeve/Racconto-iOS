import SwiftUI

struct PublicPortfolioView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel = PortfolioViewModel()
    @State private var usernameInput = ""
    @State private var submittedUsername = ""
    @State private var meLoaded = false
    @State private var meLoading = false
    @State private var showExplore = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.colorScheme) private var colorScheme

    /// 외부에서 username을 미리 주입할 때 사용 (ExploreView → 카드 탭 진입).
    /// nil이면 본인 username 또는 검색 입력 사용.
    let presetUsername: String?

    init(presetUsername: String? = nil) {
        self.presetUsername = presetUsername
    }

    // PART D-1: Asset Catalog rcCanvas — 시스템 ColorScheme + Dark Appearance로 자동 전환.
    private var portfolioBg: Color { .rcCanvas }

    var body: some View {
        content
            .task {
                // preset username (Explore 진입)이 있으면 우선 처리.
                if let preset = presetUsername, !preset.isEmpty, submittedUsername != preset {
                    submittedUsername = preset
                    await viewModel.load(username: preset)
                    return
                }
                // fetchMe는 최초 1회만 실행
                guard !meLoaded else { return }
                meLoaded = true
                meLoading = true
                await authViewModel.fetchMe()
                meLoading = false
                if let username = authViewModel.currentUsername, !username.isEmpty {
                    submittedUsername = username
                    await viewModel.load(username: username)
                }
            }
            .onAppear {
                // 탭 재진입 시 최신 데이터 갱신 (스토리 편집 등 반영).
                // isLoading 가드로 .task와의 중복 호출 방지.
                guard meLoaded, !submittedUsername.isEmpty, !viewModel.isLoading else { return }
                Task { await viewModel.load(username: submittedUsername) }
            }
            .navigationDestination(isPresented: $showExplore) {
                ExploreView()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let portfolio = viewModel.portfolio, !submittedUsername.isEmpty {
            portfolioContent(portfolio)
                .navigationTitle(submittedUsername)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        // preset username으로 진입한 경우엔 자동 navigation back 사용 — 버튼 숨김.
                        if presetUsername == nil {
                            Button("탐색") { showExplore = true }
                        }
                    }
                }
        } else if viewModel.isLoading || meLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("포트폴리오")
        } else {
            searchForm
                .navigationTitle("포트폴리오")
        }
    }

    private var searchForm: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            if authViewModel.isAuthenticated && authViewModel.currentUsername == nil {
                Text("포트폴리오를 보려면\n먼저 유저네임을 설정해 주세요.")
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                NavigationLink("설정에서 유저네임 설정") {
                    SettingsView(authViewModel: authViewModel)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("사용자 이름을 입력하면\n공개 포트폴리오를 볼 수 있습니다.")
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                TextField("사용자 이름", text: $usernameInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Button("보기") {
                    submittedUsername = usernameInput.trimmingCharacters(in: .whitespaces)
                    Task { await viewModel.load(username: submittedUsername) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(usernameInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 32)
            // 직접 입력 외에 탐색으로도 진입 가능
            Button {
                showExplore = true
            } label: {
                Label("사진가 탐색", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            if let err = viewModel.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Spacer()
            Spacer()
        }
    }

    @ViewBuilder
    private func portfolioContent(_ portfolio: PortfolioResponse) -> some View {
        if portfolio.projects.isEmpty {
            emptyPortfolio
        } else {
            portfolioGrid(portfolio)
        }
    }

    // 공개 프로젝트 없을 때 안내 — 본인 계정에서 자주 발생
    private var emptyPortfolio: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("공개된 프로젝트가 없습니다.")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("프로젝트 편집에서 '포트폴리오 공개'를\n켜면 여기에 표시됩니다.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(portfolioBg)
    }

    @ViewBuilder
    private func portfolioGrid(_ portfolio: PortfolioResponse) -> some View {
        GeometryReader { geo in
            let cols = sizeClass == .regular ? (geo.size.width > 800 ? 3 : 2) : 1
            let gridCols = Array(repeating: GridItem(.flexible(), spacing: 16), count: cols)
            ScrollView {
                if cols == 1 {
                    LazyVStack(alignment: .leading, spacing: 32) {
                        ForEach(portfolio.projects) { project in
                            NavigationLink {
                                PortfolioProjectDetailView(project: project)
                            } label: {
                                portfolioProjectCard(project)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                } else {
                    LazyVGrid(columns: gridCols, spacing: 24) {
                        ForEach(portfolio.projects) { project in
                            NavigationLink {
                                PortfolioProjectDetailView(project: project)
                            } label: {
                                portfolioProjectCard(project)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .background(portfolioBg)
        }
    }

    @ViewBuilder
    private func portfolioProjectCard(_ project: PortfolioProject) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(4.0 / 5.0, contentMode: .fit)
                .overlay {
                    if let coverUrl = project.coverImageUrl {
                        // cover variant: CF Dashboard 정의된 포트폴리오 커버 전용 crop
                        CachedImage(url: coverUrl, variant: .cover, contentMode: .fill)
                    } else {
                        Color(.secondarySystemBackground)
                    }
                }
                .clipped()
                .cornerRadius(2)

            Text(project.title)
                .font(.custom("Georgia", size: 18))
                .fontWeight(.regular)
                .lineLimit(1)
                .foregroundStyle(.primary)

            Text(project.description ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)

            if let loc = project.location, !loc.isEmpty {
                Label(loc, systemImage: "mappin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.bottom, 8)
    }
}

