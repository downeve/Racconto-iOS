import Foundation

struct Chapter: Codable, Identifiable {
    let id: String
    let projectId: String
    var title: String
    var description: String?
    var orderNum: Int
    var parentId: String?
    var updatedAt: Date
    var createdAt: Date
}

struct ChapterCreateRequest: Encodable {
    var projectId: String
    var title: String
    var description: String?
    var parentId: String?
}

struct ChapterUpdateRequest: Encodable {
    var title: String?
    var description: String?
}

struct ChapterReorderRequest: Encodable {
    var chapterIds: [String]
    var parentId: String?
}
