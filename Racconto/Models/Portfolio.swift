import Foundation
import CoreGraphics

struct PortfolioProject: Codable, Identifiable {
    let id: String
    var title: String
    var description: String?
    var coverImageUrl: String?
    var location: String?
    var chapters: [PortfolioChapter]
    var photos: [PortfolioPhoto]?
    var extraPhotos: [PortfolioPhoto]?
}

struct PortfolioChapter: Codable, Identifiable {
    let id: String
    var title: String
    var description: String?
    var items: [PortfolioChapterItem]?
    var subChapters: [PortfolioChapter]?
}

struct PortfolioPhoto: Codable, Identifiable {
    let id: String
    var imageUrl: String
    var caption: String?
    /// P-7: 이미지 원본 차원
    var width: Int?
    var height: Int?
}

struct PortfolioChapterItem: Codable {
    var itemType: String
    var id: String?
    var imageUrl: String?
    var caption: String?
    var blockLayout: String?
    var textContent: String?
    var blockId: String?
    var blockType: String?
    /// P-7: 이미지 원본 차원 (PHOTO 타입에만 의미 있음)
    var width: Int?
    var height: Int?

    /// width/height가 모두 있을 때만 비율 반환. 없으면 클라이언트가 onSuccess 폴백.
    var aspectRatio: CGFloat? {
        guard let w = width, let h = height, h > 0 else { return nil }
        return CGFloat(w) / CGFloat(h)
    }
}

struct PortfolioResponse: Codable {
    var username: String
    var theme: String?
    var projects: [PortfolioProject]
}
