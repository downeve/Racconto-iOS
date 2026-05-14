import SwiftUI

struct ChapterStackView: View {
    var viewModel: StoryViewModel
    let project: Project
    @Binding var isSelecting: Bool
    @Binding var selectedItemIds: Set<String>

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    projectHeader
                    ForEach(Array(viewModel.chapterTree.enumerated()), id: \.element.parent.id) { topIdx, node in
                        ChapterCard(
                            chapter: node.parent,
                            label: "\(topIdx + 1)",
                            isSub: false,
                            viewModel: viewModel,
                            project: project,
                            isSelecting: $isSelecting,
                            selectedItemIds: $selectedItemIds
                        )
                        .id(node.parent.id)
                        ForEach(Array(node.subs.enumerated()), id: \.element.id) { subIdx, sub in
                            ChapterCard(
                                chapter: sub,
                                label: "\(topIdx + 1).\(subIdx + 1)",
                                isSub: true,
                                viewModel: viewModel,
                                project: project,
                                isSelecting: $isSelecting,
                                selectedItemIds: $selectedItemIds
                            )
                            .id(sub.id)
                            .padding(.leading, 16)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.bottom, 100)
            }
            .onChange(of: viewModel.expandedChapterId) { _, newId in
                guard let id = newId else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(id, anchor: .top)
                }
            }
        }
    }

    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.title)
                .font(.system(.largeTitle, design: .serif))
                .fontWeight(.regular)
            Text("\(totalPhotoCount) photos · \(viewModel.chapterTree.count) chapters")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 22)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private var totalPhotoCount: Int {
        viewModel.itemsByChapter.values.reduce(0) { acc, items in
            acc + items.filter { $0.itemType == .photo }.count
        }
    }
}
