import Foundation

@Observable
class NotesViewModel {
    var notes: [Note] = []
    var isLoading = false
    var errorMessage: String?

    var pinnedNotes: [Note] { notes.filter { $0.isPinned } }
    var unpinnedNotes: [Note] { notes.filter { !$0.isPinned } }

    private let api = RaccontoAPI.shared

    func load(projectId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let all: [Note] = try await api.request("/notes/?project_id=\(projectId)")
            notes = all.filter { $0.deletedAt == nil }
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func create(projectId: String, content: String, noteType: String = "memo") async {
        do {
            let req = NoteCreateRequest(projectId: projectId, content: content, noteType: noteType)
            let note: Note = try await api.request("/notes/", method: "POST", body: req)
            notes.insert(note, at: 0)
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func update(noteId: String, content: String? = nil, noteType: String? = nil, isPinned: Bool? = nil) async {
        do {
            let req = NoteUpdateRequest(content: content, noteType: noteType, isPinned: isPinned)
            let updated: Note = try await api.request("/notes/\(noteId)", method: "PUT", body: req)
            if let idx = notes.firstIndex(where: { $0.id == noteId }) { notes[idx] = updated }
        } catch {}
    }

    func delete(noteId: String) async {
        notes.removeAll { $0.id == noteId }
        do {
            try await api.requestVoid("/notes/\(noteId)", method: "DELETE")
        } catch {}
    }

    func togglePin(_ note: Note) async {
        await update(noteId: note.id, isPinned: !note.isPinned)
    }
}
