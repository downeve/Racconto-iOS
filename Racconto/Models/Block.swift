import Foundation

struct Block: Identifiable {
    let id: String
    let chapterId: String
    let blockType: String
    let blockLayout: ChapterItem.BlockLayout
    let items: [ChapterItem]
    let minOrderNum: Int

    var photoItems: [ChapterItem] { items.filter { $0.itemType == .photo } }
    var textItem: ChapterItem? { items.first(where: { $0.itemType == .text }) }
    var firstImageUrl: String? { photoItems.first?.imageUrl }
    var isSideBySide: Bool { blockType == "side-left" || blockType == "side-right" }
}

func groupItemsIntoBlocks(_ items: [ChapterItem]) -> [Block] {
    var groups: [String: [ChapterItem]] = [:]
    var minOrderNums: [String: Int] = [:]

    for item in items {
        let key = item.blockId ?? item.id
        if minOrderNums[key] == nil || item.orderNum < (minOrderNums[key] ?? Int.max) {
            minOrderNums[key] = item.orderNum
        }
        groups[key, default: []].append(item)
    }

    return groups.map { (key, groupItems) in
        let sorted = groupItems.sorted { $0.orderInBlock < $1.orderInBlock }
        return Block(
            id: key,
            chapterId: groupItems.first?.chapterId ?? "",
            blockType: groupItems.first?.blockType ?? "default",
            blockLayout: groupItems.first?.blockLayout ?? .grid,
            items: sorted,
            minOrderNum: minOrderNums[key] ?? 0
        )
    }.sorted { $0.minOrderNum < $1.minOrderNum }
}
