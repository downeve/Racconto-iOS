import SwiftUI

struct PublicPortfolioView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel = PortfolioViewModel()
    @State private var usernameInput = ""
    @State private var submittedUsername = ""
    @State private var meLoaded = false
    @State private var meLoading = false
    @Environment(\.horizontalSizeClass) private var sizeClass

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
                                PortfolioProjectDetailView(project: project, theme: portfolio.theme)
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
                                PortfolioProjectDetailView(project: project, theme: portfolio.theme)
                            } label: {
                                portfolioProjectCard(project)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .background(themeBackground(portfolio.theme))
            .foregroundStyle(themeForeground(portfolio.theme))
        }
    }

    @ViewBuilder
    private func portfolioProjectCard(_ project: PortfolioProject) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 커버 이미지 — 항상 고정 높이 (없으면 placeholder)
            Group {
                if let coverUrl = project.coverImageUrl {
                    CachedImage(url: coverUrl, variant: .grid, contentMode: .fill)
                } else {
                    Color(.secondarySystemBackground)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipped()
            .cornerRadius(8)

            Text(project.title)
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(1)

            // 설명 — 항상 2줄 높이 확보
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

    private func themeBackground(_ theme: String?) -> Color {
        theme == "dark" ? Color.black : Color(red: 0.957, green: 0.937, blue: 0.906)
    }

    private func themeForeground(_ theme: String?) -> Color {
        theme == "dark" ? Color.white : Color(red: 0.12, green: 0.12, blue: 0.12)
    }
}

struct PortfolioProjectDetailView: View {
    let project: PortfolioProject
    let theme: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                ForEach(Array(project.chapters.enumerated()), id: \.element.id) { idx, chapter in
                    chapterSection(chapter, chapterIndex: idx + 1)
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .navigationTitle(project.title)
        .background(theme == "dark" ? Color.black : Color(red: 0.957, green: 0.937, blue: 0.906))
        .foregroundStyle(theme == "dark" ? Color.white : Color(red: 0.12, green: 0.12, blue: 0.12))
    }

    @ViewBuilder
    private func chapterSection(_ chapter: PortfolioChapter, chapterIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("챕터 \(chapterIndex)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(chapter.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                if let desc = chapter.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            PortfolioBlockView(items: chapter.items ?? [])
            ForEach(Array((chapter.subChapters ?? []).enumerated()), id: \.element.id) { subIdx, sub in
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("챕터 \(chapterIndex).\(subIdx + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(sub.title)
                            .font(.title3)
                            .fontWeight(.medium)
                        if let desc = sub.description, !desc.isEmpty {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    PortfolioBlockView(items: sub.items ?? [])
                }
                .padding(.leading, 8)
            }
        }
        Divider()
    }
}
