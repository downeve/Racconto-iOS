import Foundation

struct Project: Codable, Identifiable {
    let id: String
    var title: String
    var description: String?
    var status: ProjectStatus
    var coverImageUrl: String?
    var location: String?
    var isPublic: String          // "true" | "false" — 백엔드가 String 반환
    var orderNum: Int?
    var deletedAt: Date?
    var updatedAt: Date
    var createdAt: Date

    enum ProjectStatus: String, Codable {
        case inProgress = "in_progress"
        case completed
        case published
        case archived
    }
}

struct ProjectCreateRequest: Encodable {
    var title: String
    var description: String?
    var status: String = "in_progress"
    var location: String?
    var isPublic: String = "false"
}

struct ProjectUpdateRequest: Encodable {
    var title: String?
    var description: String?
    var status: String?
    var location: String?
    var isPublic: String?
    var coverImageUrl: String?
    var orderNum: Int?
}

struct ProjectReorderRequest: Encodable {
    var projectIds: [String]
}
