import Foundation

// MARK: - Camera Type (web tags.ts와 동일)

enum CameraType: String, CaseIterable, Codable {
    case film, digital, mobile, mixed

    var label: String {
        switch self {
        case .film:    return "필름"
        case .digital: return "디지털"
        case .mobile:  return "모바일"
        case .mixed:   return "혼합"
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
