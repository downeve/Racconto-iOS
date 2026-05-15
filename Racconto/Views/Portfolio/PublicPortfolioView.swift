import SwiftUI

struct PublicPortfolioView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel = PortfolioViewModel()
    @State private var usernameInput = ""
    @State private var submittedUsername = ""
    @State private var meLoaded = false
    @State private var meLoading = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.colorScheme) private var colorScheme

    // 웹 bg-canvas(크림) / bg-d-bg(다크) 와 동일한 시스템 연동 배경색
    private var portfolioBg: Color {
        colorScheme == .dark
            ? Color(.systemBackground)
            : Color(red: 0.957, green: 0.937, blue: 0.906)
    }

    var body: some View {
        content
            .task {
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
                        Button("다른 사용자") {
                            viewModel.portfolio = nil
                            submittedUsername = ""
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
                        CachedImage(url: coverUrl, variant: .grid, contentMode: .fill)
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

