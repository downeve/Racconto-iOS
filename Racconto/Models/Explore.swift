import Foundation

// MARK: - Camera Type (web tags.ts와 동일)

enum CameraType: String, CaseIterable, Codable {
    case film, digital, mobile, mixed

    var label: String {
        switch self {
        case .film:    return "FILM"
        case .digital: return "DIGITAL"
        case .mobile:  return "MOBILE"
        case .mixed:   return "MIXED"
        }
    }
}

// MARK: - Explore Feed Models

struct ExploreItem: Codable, Identifiable {
    let id: String
    let title: String
    let slug: String?
    let coverImageUrl: String?
    let cameraType: CameraType?
    let tags: [String]
    let photoCount: Int
    let updatedAt: String?
    let publishedAt: String?
    let author: ExploreAuthor

    struct ExploreAuthor: Codable {
        let username: String?
    }
}

struct ExploreFeedResponse: Codable {
    let items: [ExploreItem]
    let nextCursor: String?
    let hasMore: Bool
}

struct ExploreSearchUser: Codable, Identifiable {
    var id: String { username }
    let username: String
    let coverImageUrl: String?
    let latestSlug: String?
}

struct ExploreSearchResponse: Codable {
    let users: [ExploreSearchUser]
    let portfolios: [ExploreItem]
}
