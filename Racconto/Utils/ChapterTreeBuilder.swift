import Foundation

struct ChapterNode {
    let parent: Chapter
    let subs: [Chapter]
}

enum ChapterTreeBuilder {
    static func buildTree(_ chapters: [Chapter]) -> [ChapterNode] {
        let tops = chapters.filter { $0.parentId == nil }.sorted { $0.orderNum < $1.orderNum }
        return tops.map { top in
            let subs = chapters.filter { $0.parentId == top.id }.sorted { $0.orderNum < $1.orderNum }
            return ChapterNode(parent: top, subs: subs)
        }
    }
}
