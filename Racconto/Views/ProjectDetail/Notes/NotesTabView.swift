import SwiftUI

struct NotesTabView: View {
    let project: Project
    var viewModel: NotesViewModel
    @State private var showNewNote = false
    @State private var newContent = ""

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if viewModel.isLoading && viewModel.notes.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.notes.isEmpty {
                    ContentUnavailableView("노트가 없습니다", systemImage: "note.text")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if !viewModel.pinnedNotes.isEmpty {
                                Section {
                                    ForEach(viewModel.pinnedNotes) { note in
                                        noteRow(note)
                                    }
                                } header: {
                                    Text("고정됨")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 2)
                                }
                            }
                            if !viewModel.unpinnedNotes.isEmpty {
                                ForEach(viewModel.unpinnedNotes) { note in
                                    noteRow(note)
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom, 80)
                    }
                }
            }

            Button { showNewNote = true } label: {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.medium)
                    .frame(width: 52, height: 52)
                    .background(Color.primary)
                    .foregroundStyle(Color(UIColor.systemBackground))
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .alert("새 노트", isPresented: $showNewNote) {
            TextField("내용", text: $newContent)
            Button("저장") {
                let text = newContent.trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    Task {
                        await viewModel.create(projectId: project.id, content: text)
                        newContent = ""
                    }
                }
            }
            Button("취소", role: .cancel) { newContent = "" }
        }
    }

    private func noteRow(_ note: Note) -> some View {
        NoteCard(note: note, viewModel: viewModel)
            .swipeActions(edge: .leading) {
                Button {
                    Task { await viewModel.togglePin(note) }
                } label: {
                    Label(note.isPinned ? "고정 해제" : "고정", systemImage: note.isPinned ? "pin.slash" : "pin")
                }
                .tint(.orange)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    Task { await viewModel.delete(noteId: note.id) }
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
    }
}
