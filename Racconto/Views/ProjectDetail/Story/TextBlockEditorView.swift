import SwiftUI
import UIKit
import MarkdownUI

// MARK: - MarkdownEditorProxy

/// UITextView와 SwiftUI 툴바 버튼을 연결하는 브리지 객체.
/// @State로 보유하며 커서/선택 범위 기반 마크다운 삽입을 제공한다.
final class MarkdownEditorProxy {
    weak var textView: UITextView?

    /// 선택된 텍스트에만 prefix/suffix를 감싼다.
    /// 선택 없을 때: prefix 삽입 후 커서를 prefix 끝으로 이동.
    /// suffix 있는 경우: suffix까지 삽입 후 커서를 suffix 앞으로 이동.
    func insertMarkdown(prefix: String, suffix: String) {
        guard let tv = textView, let selectedRange = tv.selectedTextRange else { return }
        let selected = tv.text(in: selectedRange) ?? ""
        tv.replace(selectedRange, withText: prefix + selected + suffix)
        // 선택 없음: prefix 끝(suffix 앞)으로 커서 이동
        // 선택 있음: suffix 뒤로 커서 이동
        let offset = selected.isEmpty ? prefix.count : prefix.count + selected.count + suffix.count
        if let newPos = tv.position(from: selectedRange.start, offset: offset) {
            tv.selectedTextRange = tv.textRange(from: newPos, to: newPos)
        }
    }
}

// MARK: - MarkdownTextEditor

/// UITextView를 SwiftUI로 래핑. isScrollEnabled = false 로 두어
/// 부모 ScrollView가 스크롤을 담당하게 한다.
struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    let proxy: MarkdownEditorProxy

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = UIFont(name: "Georgia", size: 17) ?? UIFont.systemFont(ofSize: 17)
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        proxy.textView = tv
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text { tv.text = text }
        proxy.textView = tv
    }

    func makeCoordinator() -> Coordinator { Coordinator($text) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var binding: Binding<String>
        init(_ b: Binding<String>) { binding = b }

        func textViewDidChange(_ tv: UITextView) {
            binding.wrappedValue = tv.text
        }
    }
}

// MARK: - TextBlockEditorView

struct TextBlockEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let block: Block
    let chapterId: String
    var viewModel: StoryViewModel
    @State private var draft: String
    @State private var showPreview = false
    @State private var proxy = MarkdownEditorProxy()

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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(24)
                    }
                } else {
                    ScrollView {
                        MarkdownTextEditor(text: $draft, proxy: proxy)
                            .frame(minHeight: 300)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Button { proxy.insertMarkdown(prefix: "**", suffix: "**") } label: {
                                Image(systemName: "bold")
                            }
                            Button { proxy.insertMarkdown(prefix: "*", suffix: "*") } label: {
                                Image(systemName: "italic")
                            }
                            Button { proxy.insertMarkdown(prefix: "\n# ", suffix: "") } label: {
                                Text("H1").font(.callout)
                            }
                            Button { proxy.insertMarkdown(prefix: "\n- ", suffix: "") } label: {
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
}
