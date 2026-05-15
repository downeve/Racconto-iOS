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

    private static let editorFont = UIFont(name: "Georgia", size: 17) ?? UIFont.systemFont(ofSize: 17)

    private static let paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 7   // Georgia 17pt 기본 행간 ~20pt → 27pt로 확보
        return style
    }()

    private static var typingAttrs: [NSAttributedString.Key: Any] {
        [.font: editorFont, .paragraphStyle: paragraphStyle, .foregroundColor: UIColor.label]
    }

    private func styledString(_ raw: String) -> NSAttributedString {
        NSAttributedString(string: raw, attributes: Self.typingAttrs)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0)
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.typingAttributes = Self.typingAttrs
        tv.attributedText = styledString(text)
        proxy.textView = tv
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.attributedText.string != text {
            let sel = tv.selectedRange
            tv.attributedText = styledString(text)
            tv.typingAttributes = Self.typingAttrs
            // 커서 위치 복원 (범위 초과 방지)
            let len = tv.attributedText.length
            tv.selectedRange = NSRange(
                location: min(sel.location, len),
                length:   min(sel.length, max(0, len - sel.location))
            )
        }
        proxy.textView = tv
    }

    // 부모 ScrollView 폭에 맞춰 UITextView 크기 결정
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        uiView.frame.size.width = width
        let fittingSize = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(300, fittingSize.height))
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
    /// nil이면 신규 블록 생성 모드 — 저장 시 addTextItem 호출
    let block: Block?
    let chapterId: String
    var viewModel: StoryViewModel
    @State private var draft: String
    @State private var showPreview = false
    @State private var proxy = MarkdownEditorProxy()

    init(block: Block?, chapterId: String, viewModel: StoryViewModel) {
        self.block = block
        self.chapterId = chapterId
        self.viewModel = viewModel
        _draft = State(initialValue: block?.textItem?.textContent ?? "")
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
                        Markdown(preprocessMarkdown(draft.isEmpty ? "*내용을 입력하세요*" : draft))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(24)
                    }
                } else {
                    ScrollView {
                        MarkdownTextEditor(text: $draft, proxy: proxy)
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
            .navigationTitle(block == nil ? "텍스트 추가" : "텍스트 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task {
                            if let block = block, let item = block.textItem {
                                // 기존 블록 수정
                                await viewModel.updateTextItem(chapterId: chapterId, itemId: item.id, content: draft)
                            } else {
                                // 신규 블록 생성 — 내용이 없으면 취소와 동일
                                let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !content.isEmpty {
                                    await viewModel.addTextItem(chapterId: chapterId, content: content)
                                }
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
