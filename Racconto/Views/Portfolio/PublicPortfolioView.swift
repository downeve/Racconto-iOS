import SwiftUI

struct PublicPortfolioView: View {
    @State private var viewModel = PortfolioViewModel()
    @State private var usernameInput = ""
    @State private var submittedUsername = ""

    var body: some View {
        NavigationStack {
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
            } else {
                searchForm
                    .navigationTitle("포트폴리오")
            }
        }
    }

    private var searchForm: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("사용자 이름을 입력하면\n공개 포트폴리오를 볼 수 있습니다.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
            if viewModel.isLoading {
                ProgressView()
            }
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
        ScrollView {
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
        }
        .background(themeBackground(portfolio.theme))
        .foregroundStyle(themeForeground(portfolio.theme))
    }

    @ViewBuilder
    private func portfolioProjectCard(_ project: PortfolioProject) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let coverUrl = project.coverImageUrl {
                CachedImage(url: coverUrl, variant: .grid, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(8)
            }
            Text(project.title)
                .font(.title3)
                .fontWeight(.semibold)
            if let desc = project.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let loc = project.location, !loc.isEmpty {
                Label(loc, systemImage: "mappin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 8)
    }

    private func themeBackground(_ theme: String?) -> Color {
        theme == "dark" ? Color.black : Color(.systemBackground)
    }

    private func themeForeground(_ theme: String?) -> Color {
        theme == "dark" ? Color.white : Color.primary
    }
}

struct PortfolioProjectDetailView: View {
    let project: PortfolioProject
    let theme: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                ForEach(project.chapters) { chapter in
                    chapterSection(chapter)
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .navigationTitle(project.title)
        .background(theme == "dark" ? Color.black : Color(.systemBackground))
        .foregroundStyle(theme == "dark" ? Color.white : Color.primary)
    }

    @ViewBuilder
    private func chapterSection(_ chapter: PortfolioChapter) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
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
            ForEach(chapter.subChapters ?? []) { sub in
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
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
