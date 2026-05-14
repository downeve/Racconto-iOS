import SwiftUI
import MarkdownUI

struct SideBySideBlockView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    let block: Block
    let chapterId: String
    var viewModel: StoryViewModel
    @State private var showTextEditor = false
    @State private var position: String

    init(block: Block, chapterId: String, viewModel: StoryViewModel) {
        self.block = block
        self.chapterId = chapterId
        self.viewModel = viewModel
        _position = State(initialValue: block.blockType == "side-right" ? "side-right" : "side-left")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("텍스트 위치", selection: $position) {
                    Label("텍스트 왼쪽", systemImage: "text.alignleft").tag("side-left")
                    Label("텍스트 오른쪽", systemImage: "text.alignright").tag("side-right")
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: position) { _, newPosition in
                    guard let textItem = block.textItem else { return }
                    Task {
                        await viewModel.setSideBySide(
                            chapterId: chapterId,
                            textItemId: textItem.id,
                            photoBlockId: block.id,
                            position: newPosition
                        )
                    }
                }

                Divider()

                ScrollView {
                    if sizeClass == .regular {
                        HStack(alignment: .top, spacing: 16) {
                            sideContent
                        }
                        .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            sideContent
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Side-by-Side 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .sheet(isPresented: $showTextEditor) {
                TextBlockEditorView(block: block, chapterId: chapterId, viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private var sideContent: some View {
        let isTextLeft = position == "side-left"
        if isTextLeft {
            textSection
            photosSection
        } else {
            photosSection
            textSection
        }
    }

    private var photosSection: some View {
        VStack(spacing: 8) {
            ForEach(block.photoItems) { item in
                CachedImage(url: item.imageUrl, variant: .grid, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()
                    .cornerRadius(6)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let content = block.textItem?.textContent, !content.isEmpty {
                Markdown(content)
                    .font(.body)
            } else {
                Text("텍스트 없음")
                    .foregroundStyle(.tertiary)
            }
            Button("텍스트 편집") { showTextEditor = true }
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(6)
    }
}
