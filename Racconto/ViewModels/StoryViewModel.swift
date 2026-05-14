import Foundation

@Observable
class StoryViewModel {
    var chapters: [Chapter] = []
    var itemsByChapter: [String: [ChapterItem]] = [:]
    var isLoading = false
    var errorMessage: String?
    private var projectId = ""

    var chapterTree: [ChapterNode] { ChapterTreeBuilder.buildTree(chapters) }

    private var _expandedChapterId: String?

    var expandedChapterId: String? {
        get { _expandedChapterId ?? chapterTree.first?.parent.id }
        set { _expandedChapterId = newValue }
    }

    func toggleExpanded(_ chapterId: String) {
        if _expandedChapterId == chapterId { return }
        _expandedChapterId = chapterId
    }

    func blocks(for chapterId: String) -> [Block] {
        groupItemsIntoBlocks(itemsByChapter[chapterId] ?? [])
    }

    private let api = RaccontoAPI.shared

    func load(projectId: String) async {
        self.projectId = projectId
        isLoading = true
        defer { isLoading = false }
        do {
            chapters = try await api.request("/chapters/?project_id=\(projectId)")
            await withTaskGroup(of: Void.self) { group in
                for chapter in chapters {
                    group.addTask { await self.loadItems(for: chapter.id) }
                }
            }
            _expandedChapterId = chapterTree.first?.parent.id
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func loadItems(for chapterId: String) async {
        do {
            let items: [ChapterItem] = try await api.request("/chapters/\(chapterId)/items")
            itemsByChapter[chapterId] = items
        } catch {}
    }

    func reloadAllItems() async {
        await withTaskGroup(of: Void.self) { group in
            for chapter in chapters {
                group.addTask { await self.loadItems(for: chapter.id) }
            }
        }
    }

    // MARK: - Chapter CRUD

    func createChapter(title: String, description: String? = nil, parentId: String? = nil) async {
        do {
            let req = ChapterCreateRequest(projectId: projectId, title: title, description: description?.isEmpty == true ? nil : description, parentId: parentId)
            let chapter: Chapter = try await api.request("/chapters/", method: "POST", body: req)
            chapters.append(chapter)
            itemsByChapter[chapter.id] = []
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func updateChapter(id: String, title: String, description: String? = nil) async {
        do {
            let req = ChapterUpdateRequest(title: title, description: description?.isEmpty == true ? nil : description)
            let updated: Chapter = try await api.request("/chapters/\(id)", method: "PUT", body: req)
            if let idx = chapters.firstIndex(where: { $0.id == id }) { chapters[idx] = updated }
        } catch {}
    }

    func deleteChapter(id: String) async {
        do {
            try await api.requestVoid("/chapters/\(id)", method: "DELETE")
            chapters.removeAll { $0.id == id || $0.parentId == id }
            itemsByChapter.removeValue(forKey: id)
            if _expandedChapterId == id || chapters.first(where: { $0.id == _expandedChapterId }) == nil {
                _expandedChapterId = chapterTree.first?.parent.id
            }
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func moveChapterUp(_ chapter: Chapter) async {
        var siblings = chapters
            .filter { $0.parentId == chapter.parentId }
            .sorted { $0.orderNum < $1.orderNum }
        guard let idx = siblings.firstIndex(where: { $0.id == chapter.id }), idx > 0 else { return }
        siblings.swapAt(idx, idx - 1)
        applyLocalChapterOrder(siblings)
        await reorderChapters(ids: siblings.map(\.id), parentId: chapter.parentId)
    }

    func moveChapterDown(_ chapter: Chapter) async {
        var siblings = chapters
            .filter { $0.parentId == chapter.parentId }
            .sorted { $0.orderNum < $1.orderNum }
        guard let idx = siblings.firstIndex(where: { $0.id == chapter.id }), idx < siblings.count - 1 else { return }
        siblings.swapAt(idx, idx + 1)
        applyLocalChapterOrder(siblings)
        await reorderChapters(ids: siblings.map(\.id), parentId: chapter.parentId)
    }

    private func applyLocalChapterOrder(_ siblings: [Chapter]) {
        for (i, ch) in siblings.enumerated() {
            if let idx = chapters.firstIndex(where: { $0.id == ch.id }) {
                chapters[idx].orderNum = i
            }
        }
    }

    private func reorderChapters(ids: [String], parentId: String?) async {
        do {
            let req = ChapterReorderRequest(chapterIds: ids, parentId: parentId)
            try await api.requestVoid("/chapters/reorder", method: "PUT", body: req)
            if !projectId.isEmpty { await load(projectId: projectId) }
        } catch {}
    }

    // MARK: - Items

    func addTextItem(chapterId: String, content: String) async {
        do {
            let req = TextItemAddRequest(textContent: content)
            let item: ChapterItem = try await api.request("/chapters/\(chapterId)/texts", method: "POST", body: req)
            itemsByChapter[chapterId, default: []].append(item)
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func updateTextItem(chapterId: String, itemId: String, content: String) async {
        do {
            let req = TextItemUpdateRequest(textContent: content)
            let updated: ChapterItem = try await api.request("/chapters/\(chapterId)/texts/\(itemId)", method: "PUT", body: req)
            if var items = itemsByChapter[chapterId], let idx = items.firstIndex(where: { $0.id == itemId }) {
                items[idx] = updated
                itemsByChapter[chapterId] = items
            }
        } catch {}
    }

    func deleteItem(chapterId: String, itemId: String) async {
        do {
            try await api.requestVoid("/chapters/\(chapterId)/items/\(itemId)", method: "DELETE")
            itemsByChapter[chapterId]?.removeAll { $0.id == itemId }
        } catch {}
    }

    func moveToBlock(chapterId: String, itemId: String, targetBlockId: String) async {
        do {
            let req = MoveToBlockRequest(itemId: itemId, targetBlockId: targetBlockId)
            try await api.requestVoid("/chapters/\(chapterId)/items/move-to-block", method: "PUT", body: req)
            await loadItems(for: chapterId)
        } catch {}
    }

    func reorderBlock(chapterId: String, blockId: String, itemIds: [String]) async {
        do {
            let req = BlockReorderRequest(itemIds: itemIds)
            try await api.requestVoid("/chapters/\(chapterId)/blocks/\(blockId)/reorder", method: "PUT", body: req)
            await loadItems(for: chapterId)
        } catch {}
    }

    func changeBlockLayout(chapterId: String, blockId: String, layout: ChapterItem.BlockLayout) async {
        do {
            let req = BlockLayoutRequest(blockLayout: layout.rawValue)
            try await api.requestVoid("/chapters/\(chapterId)/blocks/\(blockId)/layout", method: "PUT", body: req)
            if var items = itemsByChapter[chapterId] {
                for i in items.indices where items[i].blockId == blockId {
                    items[i].blockLayout = layout
                }
                itemsByChapter[chapterId] = items
            }
        } catch {}
    }

    func moveBlockUp(chapterId: String, blockId: String) async {
        var currentBlocks = blocks(for: chapterId)
        guard let idx = currentBlocks.firstIndex(where: { $0.id == blockId }), idx > 0 else { return }
        currentBlocks.swapAt(idx, idx - 1)
        applyLocalBlockOrder(chapterId: chapterId, blocks: currentBlocks)
        await syncBlocks(chapterId: chapterId, blocks: currentBlocks)
    }

    func moveBlockDown(chapterId: String, blockId: String) async {
        var currentBlocks = blocks(for: chapterId)
        guard let idx = currentBlocks.firstIndex(where: { $0.id == blockId }), idx < currentBlocks.count - 1 else { return }
        currentBlocks.swapAt(idx, idx + 1)
        applyLocalBlockOrder(chapterId: chapterId, blocks: currentBlocks)
        await syncBlocks(chapterId: chapterId, blocks: currentBlocks)
    }

    func moveBlockLocally(chapterId: String, from: Int, to: Int) {
        var currentBlocks = blocks(for: chapterId)
        guard from != to, currentBlocks.indices.contains(from), currentBlocks.indices.contains(to) else { return }
        let block = currentBlocks.remove(at: from)
        currentBlocks.insert(block, at: to)
        applyLocalBlockOrder(chapterId: chapterId, blocks: currentBlocks)
    }

    func syncBlockOrder(chapterId: String) async {
        let currentBlocks = blocks(for: chapterId)
        await syncBlocks(chapterId: chapterId, blocks: currentBlocks)
    }

    private func applyLocalBlockOrder(chapterId: String, blocks: [Block]) {
        var updated: [ChapterItem] = []
        var n = 0
        for block in blocks {
            for item in block.items {
                var copy = item
                copy.orderNum = n
                n += 1
                updated.append(copy)
            }
        }
        itemsByChapter[chapterId] = updated
    }

    // syncBlocks에서 items 배열을 만들 때 blockId 포함하는 헬퍼
    func setSideBySide(chapterId: String, textItemId: String, photoBlockId: String, position: String) async {
        struct Body: Encodable { let textItemId, photoBlockId, position: String }
        do {
            try await api.requestVoid("/chapters/\(chapterId)/side-by-side", method: "PUT",
                body: Body(textItemId: textItemId, photoBlockId: photoBlockId, position: position))
            await reloadAllItems()
        } catch {}
    }

    func cancelSideBySide(chapterId: String, textItemId: String) async {
        struct Body: Encodable { let textItemId: String }
        do {
            try await api.requestVoid("/chapters/\(chapterId)/side-by-side/cancel", method: "PUT",
                body: Body(textItemId: textItemId))
            await reloadAllItems()
        } catch {}
    }

    private func makeSyncItems(from blocks: [Block]) -> [ItemSyncData] {
        var result: [ItemSyncData] = []
        var n = 0
        for block in blocks {
            for item in block.items {
                result.append(ItemSyncData(id: item.id, orderNum: n, orderInBlock: item.orderInBlock, blockId: item.blockId))
                n += 1
            }
        }
        return result
    }

    private func syncBlocks(chapterId: String, blocks: [Block]) async {
        let syncItems = makeSyncItems(from: blocks)
        do {
            try await api.requestVoid("/chapters/\(chapterId)/items/bulk-sync", method: "PUT", body: BulkSyncRequest(items: syncItems))
            await loadItems(for: chapterId)
        } catch {}
    }
}
