import SwiftUI
import MarkdownUI

// MARK: - Chapter Visibility Tracking

private struct ChapterMinY: Equatable {
    let id: String
    let index: Int
    let minY: CGFloat
}

private struct ChapterMinYKey: PreferenceKey {
    static var defaultValue: [ChapterMinY] = []
    static func reduce(value: inout [ChapterMinY], nextValue: () -> [ChapterMinY]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - PortfolioProjectDetailView

struct PortfolioProjectDetailView: View {
    let project: PortfolioProject
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var fontMenuOpen = false
    @State private var activeChapterIndex: Int = 0

    private var portfolioBg: Color {
        colorScheme == .dark
            ? Color(.systemBackground)
            : Color(red: 0.957, green: 0.937, blue: 0.906)
    }

    private var activeChapter: PortfolioChapter? {
        project.chapters.indices.contains(activeChapterIndex)
            ? project.chapters[activeChapterIndex]
            : nil
    }

    private var progress: Double {
        guard project.chapters.count > 1 else { return 1 }
        return Double(activeChapterIndex + 1) / Double(project.chapters.count)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                projectHeader
                    .padding(.horizontal, 22)
                    .padding(.top, 28)

                ForEach(Array(project.chapters.enumerated()), id: \.element.id) { idx, chapter in
                    chapterSection(chapter, index: idx)
                        .id(chapter.id)
                        .padding(.horizontal, 22)
                        .padding(.top, idx == 0 ? 40 : 64)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ChapterMinYKey.self,
                                    value: [ChapterMinY(
                                        id: chapter.id,
                                        index: idx,
                                        minY: geo.frame(in: .named("scroll")).minY
                                    )]
                                )
                            }
                        )
                }
            }
            .padding(.bottom, 40)
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ChapterMinYKey.self) { positions in
            let sorted = positions.sorted { $0.index < $1.index }
            // 스크롤 뷰 상단 기준 100pt 아래까지 진입한 챕터 중 가장 마지막
            let active = sorted.last { $0.minY <= 100 } ?? sorted.first
            if let active {
                activeChapterIndex = active.index
            }
        }
        .background(portfolioBg)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Library")
                    }
                }
            }
            ToolbarItem(placement: .principal) {
                Text(project.title)
                    .font(.custom("Georgia-Italic", size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button { fontMenuOpen.toggle() } label: {
                        Text("Aa")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Button { } label: {
                        Image(systemName: "bookmark")
                    }
                }
            }
            ToolbarItem(placement: .bottomBar) {
                chapterScrubber
            }
        }
        .sheet(isPresented: $fontMenuOpen) {
            ReaderSettingsSheet()
                .presentationDetents([.height(280)])
        }
    }

    // MARK: - Project Header

    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(project.title)
                .font(.custom("Georgia", size: 34))
                .fontWeight(.regular)
                .tracking(-0.5)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                if let loc = project.location, !loc.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin")
                            .font(.system(size: 11))
                        Text(loc)
                    }
                    Text("·")
                }
                Text("\(project.chapters.count) chapters")
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.top, 10)

            if let desc = project.description, !desc.isEmpty {
                Text(desc)
                    .font(.custom("Georgia", size: 16))
                    .foregroundStyle(.secondary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
            }
        }
    }

    // MARK: - Chapter Section

    @ViewBuilder
    private func chapterSection(_ chapter: PortfolioChapter, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            chapterHeader(chapter, number: index + 1, isTop: true)
            PortfolioBlockView(items: chapter.items ?? [])

            ForEach(Array((chapter.subChapters ?? []).enumerated()), id: \.element.id) { subIdx, sub in
                VStack(alignment: .leading, spacing: 16) {
                    chapterHeader(sub, number: subIdx + 1, isTop: false)
                    PortfolioBlockView(items: sub.items ?? [])
                }
                .padding(.top, 32)
            }
        }
    }

    @ViewBuilder
    private func chapterHeader(_ chapter: PortfolioChapter, number: Int, isTop: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isTop {
                // 대형 챕터 번호 + hairline
                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    Text(String(format: "%02d", number))
                        .font(.custom("Georgia", size: 52))
                        .fontWeight(.light)
                        .foregroundStyle(Color(red: 0.659, green: 0.263, blue: 0.122))
                        .lineLimit(1)
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(maxWidth: .infinity)
                        .frame(height: 0.5)
                }
                .padding(.bottom, 12)

                Text(chapter.title)
                    .font(.custom("Georgia", size: 26))
                    .fontWeight(.regular)
                    .tracking(-0.3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // 서브챕터 eyebrow + 타이틀
                Text("Section \(String(format: "%02d", number))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)

                Text(chapter.title)
                    .font(.custom("Georgia", size: 20))
                    .fontWeight(.regular)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let desc = chapter.description, !desc.isEmpty {
                Text(desc)
                    .font(.custom("Georgia-Italic", size: 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Chapter Scrubber

    private var chapterScrubber: some View {
        HStack(spacing: 8) {
            Text("\(activeChapterIndex + 1)/\(project.chapters.count)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(minWidth: 30, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 3)
                    Capsule()
                        .fill(Color(red: 0.659, green: 0.263, blue: 0.122))
                        .frame(width: max(0, geo.size.width * progress), height: 3)
                }
            }
            .frame(height: 3)

            Text(activeChapter?.title ?? "")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 60, alignment: .trailing)
        }
    }
}
