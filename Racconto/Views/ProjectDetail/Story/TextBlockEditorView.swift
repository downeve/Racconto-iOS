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
                Picker("", selection: $showPreview) {
                    Text("작성").tag(false)
                    Text("미리보기").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                if showPreview {
                    ScrollView {
                        Markdown(draft.isEmpty ? "*내용을 입력하세요*" : draft)
                            .padding(24)
                    }
                } else {
                    TextEditor(text: $draft)
                        .font(.system(.title3, design: .serif))
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Button { insertMarkdown("**", "**") } label: {
                                    Image(systemName: "bold")
                                }
                                Button { insertMarkdown("*", "*") } label: {
                                    Image(systemName: "italic")
                                }
                                Button { insertMarkdown("# ", "") } label: {
                                    Text("H1").font(.callout)
                                }
                                Button { insertMarkdown("- ", "") } label: {
                                    Image(systemName: "list.bullet")
                                }
                                Spacer()
                                Text("\(wordCount) words")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button {
                                    UIApplication.shared.sendAction(
                                        #selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil
                                    )
                                } label: {
                                    Image(systemName: "keyboard.chevron.compact.down")
                                }
                            }
                        }
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

    private var wordCount: Int {
        draft.split { $0.isWhitespace }.count
    }

    // 마크다운 토큰 삽입 (커서 위치 무관하게 앞뒤 삽입 — 실제 커서 삽입은 후속 PR)
    private func insertMarkdown(_ prefix: String, _ suffix: String) {
        draft = prefix + draft + suffix
    }
}
