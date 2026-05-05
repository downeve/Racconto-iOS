import SwiftUI

struct NoteCard: View {
    let note: Note
    var viewModel: NotesViewModel
    @State private var showEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let type = note.noteType, !type.isEmpty {
                    Text(type)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(4)
                }
                Spacer()
                Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(note.content)
                .lineLimit(3)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture { showEditor = true }
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

    init(note: Note, viewModel: NotesViewModel) {
        self.note = note
        self.viewModel = viewModel
        _content = State(initialValue: note.content)
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $content)
                .padding()
                .navigationTitle("노트")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") {
                            Task {
                                await viewModel.update(noteId: note.id, content: content)
                                dismiss()
                            }
                        }
                    }
                }
        }
    }
}
