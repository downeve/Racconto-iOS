import SwiftUI

struct NotesTabView: View {
    let project: Project
    var viewModel: NotesViewModel
    @State private var isComposing = false
    @State private var newContent = ""
    @State private var newNoteType = "memo"
    @State private var filterType: String? = nil
    @State private var filterPinned = false
    @FocusState private var composerFocused: Bool

    private var filteredNotes: [Note] {
        viewModel.notes.filter { note in
            (filterPinned ? note.isPinned : true) &&
            (filterType == nil || note.noteType == filterType)
        }
    }
    private var filteredPinned: [Note] { filteredNotes.filter { $0.isPinned } }
    private var filteredUnpinned: [Note] { filteredNotes.filter { !$0.isPinned } }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 8) {
                    // 필터 바
                    filterBar
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // 인라인 입력창
                    if isComposing {
                        composerCard
                            .padding(.horizontal)
                    }

                    if viewModel.isLoading && viewModel.notes.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if viewModel.notes.isEmpty && !isComposing {
                        emptyComposer
                            .padding(.horizontal)
                    } else {
                        if !filteredPinned.isEmpty {
                            Section {
                                ForEach(filteredPinned) { note in
                                    noteRow(note)
                                        .padding(.horizontal)
                                }
                            } header: {
                                Text("고정됨")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.top, 4)
                            }
                        }
                        ForEach(filteredUnpinned) { note in
                            noteRow(note)
                                .padding(.horizontal)
                        }
                        if filteredNotes.isEmpty && !isComposing {
                            Text("해당하는 노트가 없습니다.")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 32)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.bottom, 80)
            }

            if !isComposing {
                Button {
                    newContent = ""
                    newNoteType = "memo"
                    isComposing = true
                    composerFocused = true
                } label: {
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
        }
    }

    // MARK: - 필터 바

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip(label: "전체", count: viewModel.notes.count, isActive: !filterPinned && filterType == nil) {
                    filterPinned = false
                    filterType = nil
                }
                filterChip(label: "고정됨", count: viewModel.pinnedNotes.count, isActive: filterPinned) {
                    filterPinned = true
                    filterType = nil
                }
                ForEach(noteTypeList, id: \.value) { type in
                    let count = viewModel.notes.filter { ($0.noteType ?? "memo") == type.value }.count
                    filterChip(label: type.label, count: count, isActive: !filterPinned && filterType == type.value) {
                        filterPinned = false
                        filterType = type.value
                    }
                }
            }
        }
    }

    private func filterChip(label: String, count: Int, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .fontWeight(isActive ? .semibold : .regular)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(isActive ? .primary : .tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? Color(.label).opacity(0.12) : Color(.tertiarySystemBackground))
            .foregroundStyle(isActive ? Color(.label) : Color.secondary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 카테고리 칩 피커 (작성 카드용)

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(noteTypeList, id: \.value) { type in
                    Button {
                        newNoteType = type.value
                    } label: {
                        Text(type.label)
                            .font(.caption)
                            .fontWeight(newNoteType == type.value ? .semibold : .regular)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(newNoteType == type.value ? type.color : Color(.tertiarySystemBackground))
                            .foregroundStyle(newNoteType == type.value ? type.dotColor : Color.secondary)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 인라인 작성 카드 (노트 있을 때 상단)

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            categoryPicker

            TextEditor(text: $newContent)
                .focused($composerFocused)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)

            HStack {
                Spacer()
                Button("취소") {
                    isComposing = false
                    newContent = ""
                    newNoteType = "memo"
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Button("저장") {
                    saveNote()
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .disabled(newContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    // MARK: - 빈 상태 입력창

    private var emptyComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            categoryPicker

            TextEditor(text: $newContent)
                .focused($composerFocused)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if newContent.isEmpty {
                        Text("노트를 작성하세요...")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Spacer()
                Button("저장") {
                    saveNote()
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .disabled(newContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    // MARK: - 노트 행

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

    // MARK: - 저장

    private func saveNote() {
        let text = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Task {
            await viewModel.create(projectId: project.id, content: text, noteType: newNoteType)
            newContent = ""
            newNoteType = "memo"
            isComposing = false
        }
    }
}
