import Foundation

struct PortfolioProject: Codable, Identifiable {
    let id: String
    var title: String
    var description: String?
    var coverImageUrl: String?
    var location: String?
    var chapters: [PortfolioChapter]
    var photos: [PortfolioPhoto]
    var extraPhotos: [PortfolioPhoto]
}

struct PortfolioChapter: Codable, Identifiable {
    let id: String
    var title: String
    var description: String?
    var items: [PortfolioChapterItem]
    var subChapters: [PortfolioChapter]
}

struct PortfolioPhoto: Codable, Identifiable {
    let id: String
    var imageUrl: String
    var caption: String?
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
}

struct PortfolioResponse: Codable {
    var username: String
    var theme: String?
    var projects: [PortfolioProject]
}
