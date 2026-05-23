import SwiftUI
import MarkdownUI

// 단일 \n → 마크다운 hard break (줄 끝 공백 2개 + \n), 연속 \n은 단락 구분으로 유지
private func applyHardBreaks(_ text: String) -> String {
    text.replacingOccurrences(of: "([^\n])\n([^\n])", with: "$1  \n$2", options: .regularExpression)
}

struct NoteCard: View {
    let note: Note
    var viewModel: NotesViewModel
    @State private var showEditor = false

    /// iOS 네이티브 AttributedString(markdown:)는 인라인 마크다운(볼드/이탤릭/링크/코드)만 지원.
    /// 헤딩(`#`)이나 리스트는 일반 텍스트로 보이지만 카드 미리보기 용도엔 충분.
    private var previewText: Text {
        let raw = note.content
        if let attr = try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attr)
        }
        return Text(raw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 헤더: 카테고리 배지 + 핀 + 날짜
            HStack(spacing: 6) {
                let info = noteTypeInfo(for: note.noteType)
                Text(info.label)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(info.color)
                    .foregroundStyle(info.dotColor)
                    .cornerRadius(4)

                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Spacer()
                Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // 미리보기는 줄 단위 truncate가 자연스러움. iOS 네이티브 마크다운(인라인만)으로 전환.
            // 전체 마크다운 렌더(헤딩 크기 등)는 편집창에서 처리.
            previewText
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture { showEditor = true }
        .contextMenu {
            Button {
                Task { await viewModel.togglePin(note) }
            } label: {
                Label(note.isPinned ? "고정 해제" : "고정", systemImage: note.isPinned ? "pin.slash" : "pin")
            }
            Divider()
            Button(role: .destructive) {
                Task { await viewModel.delete(noteId: note.id) }
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showEditor) {
            NoteEditorView(note: note, viewModel: viewModel)
        }
    }
}

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let note: Note
    var viewModel: NotesViewModel
    @State private var content: String
    @State private var selectedType: String
    @State private var showPreview = false

    init(note: Note, viewModel: NotesViewModel) {
        self.note = note
        self.viewModel = viewModel
        _content = State(initialValue: note.content)
        _selectedType = State(initialValue: note.noteType ?? "memo")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 카테고리 + 편집/미리보기
                HStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(noteTypeList, id: \.value) { type in
                                Button {
                                    selectedType = type.value
                                } label: {
                                    Text(type.label)
                                        .font(.caption)
                                        .fontWeight(selectedType == type.value ? .semibold : .regular)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(selectedType == type.value ? type.color : Color(.tertiarySystemBackground))
                                        .foregroundStyle(selectedType == type.value ? type.dotColor : Color.secondary)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(selectedType == type.value ? type.dotColor.opacity(0.4) : Color.clear, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }

                    Picker("", selection: $showPreview) {
                        Text("편집").tag(false)
                        Text("미리보기").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                    .padding(.trailing)
                }

                Divider()

                if showPreview {
                    ScrollView {
                        Markdown(content.isEmpty ? "*내용 없음*" : applyHardBreaks(content))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    TextEditor(text: $content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
            .navigationTitle("노트")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Button {
                        Task { await viewModel.togglePin(note) }
                    } label: {
                        Image(systemName: note.isPinned ? "pin.fill" : "pin")
                            .foregroundStyle(note.isPinned ? .orange : .secondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task {
                            await viewModel.update(noteId: note.id, content: content, noteType: selectedType)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
