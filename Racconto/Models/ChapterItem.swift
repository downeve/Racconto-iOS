import Foundation

struct ChapterItem: Codable, Identifiable {
    let id: String
    let chapterId: String
    var orderNum: Int
    var itemType: ItemType
    var blockType: String         // "default" | "side-left" | "side-right"
    var blockLayout: BlockLayout
    var blockId: String?
    var orderInBlock: Int
    // PHOTO 전용
    var photoId: String?
    var imageUrl: String?
    var caption: String?
    // TEXT 전용
    var textContent: String?

    enum ItemType: String, Codable {
        case photo = "PHOTO"
        case text = "TEXT"
    }

    enum BlockLayout: String, Codable {
        case grid, wide, single
    }
}

struct PhotoItemAddRequest: Encodable {
    var photoId: String
    var blockId: String?
}

struct TextItemAddRequest: Encodable {
    var textContent: String
    var blockId: String?
}

struct TextItemUpdateRequest: Encodable {
    var textContent: String
}

struct MoveToBlockRequest: Encodable {
    var itemId: String
    var targetBlockId: String     // 기존 block_id 또는 "new"
}

struct BlockReorderRequest: Encodable {
    var itemIds: [String]
}

struct BlockLayoutRequest: Encodable {
    var blockLayout: String
}

struct ItemSyncData: Encodable {
    var id: String
    var orderNum: Int
    var orderInBlock: Int
    var blockId: String?
}

struct BulkSyncRequest: Encodable {
    var items: [ItemSyncData]
}
