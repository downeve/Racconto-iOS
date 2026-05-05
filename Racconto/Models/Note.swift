import Foundation

struct Note: Codable, Identifiable {
    let id: String
    let projectId: String
    var content: String
    var noteType: String?
    var isPinned: Bool
    var photoId: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
}

struct NoteCreateRequest: Encodable {
    var projectId: String
    var content: String
    var noteType: String?
    var isPinned: Bool?
    var photoId: String?
}

struct NoteUpdateRequest: Encodable {
    var content: String?
    var isPinned: Bool?
}
