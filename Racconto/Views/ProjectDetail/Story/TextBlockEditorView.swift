import SwiftUI
import MarkdownUI

struct TextBlockEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let block: Block
    let chapterId: String
    var viewModel: StoryViewModel
    @State private var draft: String
    @State private var showPreview = false

    init(block: Block, chapterId: String, viewModel: StoryViewModel) {
        self.block = block
        self.chapterId = chapterId
        self.viewModel = viewModel
        _draft = State(initialValue: block.textItem?.textContent ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Toggle("미리보기", isOn: $showPreview)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                Divider()

                if showPreview {
                    ScrollView {
                        Markdown(draft.isEmpty ? "*내용을 입력하세요*" : draft)
                            .padding()
                    }
                } else {
                    TextEditor(text: $draft)
                        .font(.body)
                        .padding(8)
                }
            }
            .navigationTitle("텍스트 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task {
                            if let item = block.textItem {
                                await viewModel.updateTextItem(chapterId: chapterId, itemId: item.id, content: draft)
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
