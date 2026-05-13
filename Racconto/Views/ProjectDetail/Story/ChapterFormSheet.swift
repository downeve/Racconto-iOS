import SwiftUI

struct ChapterFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let confirmLabel: String
    let initialTitle: String
    let initialDescription: String
    let onConfirm: (String, String) -> Void

    @State private var chapterTitle: String
    @State private var chapterDescription: String

    init(title: String, confirmLabel: String, initialTitle: String = "", initialDescription: String = "", onConfirm: @escaping (String, String) -> Void) {
        self.title = title
        self.confirmLabel = confirmLabel
        self.initialTitle = initialTitle
        self.initialDescription = initialDescription
        self.onConfirm = onConfirm
        _chapterTitle = State(initialValue: initialTitle)
        _chapterDescription = State(initialValue: initialDescription)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("제목") {
                    TextField("챕터 제목", text: $chapterTitle)
                }
                Section("설명 (선택)") {
                    TextField("챕터 설명", text: $chapterDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmLabel) {
                        onConfirm(
                            chapterTitle.trimmingCharacters(in: .whitespaces),
                            chapterDescription.trimmingCharacters(in: .whitespaces)
                        )
                        dismiss()
                    }
                    .disabled(chapterTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
