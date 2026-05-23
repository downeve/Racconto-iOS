import Foundation
import UIKit

@MainActor
@Observable
class StoryViewModel {
    var chapters: [Chapter] = []
    var itemsByChapter: [String: [ChapterItem]] = [:]
    var isLoading = false
    var errorMessage: String?
    private var projectId = ""

    var chapterTree: [ChapterNode] { ChapterTreeBuilder.buildTree(chapters) }

    var expandedChapterId: String? = nil

    func toggleExpanded(_ chapterId: String) {
        if expandedChapterId == chapterId { return }
        expandedChapterId = chapterId
        // 아직 로드되지 않은 챕터를 펼치면 즉시 fetch (lazy load 경로 보강).
        if itemsByChapter[chapterId] == nil {
            Task { await loadItems(for: chapterId) }
        }
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
            // 첫 챕터를 즉시 펼침 + 해당 챕터 아이템만 우선 로드 → 진입 체감속도 개선.
            // 나머지 챕터 아이템은 백그라운드로 점진 로드 (Preview 진입 시 이미 캐시되어 있음).
            let firstChapterId = chapterTree.first?.parent.id
            expandedChapterId = firstChapterId
            if let firstChapterId {
                await loadItems(for: firstChapterId)
            }
            // 나머지 챕터 lazy 로드 — load() 반환 후 백그라운드에서 진행.
            let remainingIds = chapters.map(\.id).filter { $0 != firstChapterId }
            Task { [weak self] in
                guard let self else { return }
                await withTaskGroup(of: Void.self) { group in
                    for id in remainingIds {
                        group.addTask { await self.loadItems(for: id) }
                    }
                }
            }
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func loadItems(for chapterId: String) async {
        do {
            let items: [ChapterItem] = try await api.request("/chapters/\(chapterId)/items")
            itemsByChapter[chapterId] = items
        } catch let err as APIError {
            errorMessage = err.errorDescription
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
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func deleteChapter(id: String) async {
        do {
            try await api.requestVoid("/chapters/\(id)", method: "DELETE")
            chapters.removeAll { $0.id == id || $0.parentId == id }
            itemsByChapter.removeValue(forKey: id)
            if expandedChapterId == id || chapters.first(where: { $0.id == expandedChapterId }) == nil {
                expandedChapterId = chapterTree.first?.parent.id
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
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    // MARK: - Items

    func addTextItem(chapterId: String, content: String) async {
        do {
            // 서버가 빈 문자열 거부(strip 후 empty → 400).
            // \u{200B}(zero-width space)는 파이썬 strip()에서 제거되지 않아 검증 통과,
            // 에디터에서는 보이지 않으므로 사용자에게는 빈 상태로 표시됨.
            let safeContent = content.isEmpty ? "\u{200B}" : content
            let req = TextItemAddRequest(textContent: safeContent)
            let item: ChapterItem = try await api.request("/chapters/\(chapterId)/texts", method: "POST", body: req)
            itemsByChapter[chapterId, default: []].append(item)
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func addPhotosToChapter(images: [(image: UIImage, data: Data, filename: String)], chapterId: String) async {
        for item in images {
            do {
                let exif = EXIFExtractor.extract(from: item.data)
                // 1. CF 업로드 URL 획득
                let urlResp: CFUploadURLResponse = try await api.request("/photos/cf-upload-url")
                // 2. 리사이즈 + Cloudflare 업로드
                let imageData = ImageResizer.resize(item.image)
                let imageUrl = try await uploadToCloudflare(data: imageData, uploadUrl: urlResp.uploadUrl, imageId: urlResp.id)
                // 3. 사진 메타데이터 저장
                let photoReq = PhotoMetadataRequest(
                    projectId: projectId,
                    imageUrl: imageUrl,
                    originalFilename: item.filename,
                    camera: exif.camera, lens: exif.lens,
                    iso: exif.iso,
                    shutterSpeed: exif.shutterSpeed, aperture: exif.aperture,
                    focalLength: exif.focalLength,
                    gpsLat: exif.gpsLat, gpsLng: exif.gpsLng,
                    takenAt: exif.takenAt
                )
                let photo: Photo = try await api.request("/photos/", method: "POST", body: photoReq)
                // 4. 챕터에 연결
                struct AddReq: Encodable { let photoId: String }
                try await api.requestVoid("/chapters/\(chapterId)/photos", method: "POST", body: AddReq(photoId: photo.id))
                await loadItems(for: chapterId)
            } catch let err as APIError {
                errorMessage = err.errorDescription
            } catch {}
        }
    }

    private func uploadToCloudflare(data: Data, uploadUrl: String, imageId: String) async throws -> String {
        guard let url = URL(string: uploadUrl) else { throw URLError(.badURL) }
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        // multipart boundary는 ASCII만 사용 — utf8 인코딩 실패 가능성 없음. 규칙상 옵셔널 바인딩.
        let head = "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n"
        let tail = "\r\n--\(boundary)--\r\n"
        guard let headData = head.data(using: .utf8),
              let tailData = tail.data(using: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        var body = Data()
        body.append(headData)
        body.append(data)
        body.append(tailData)
        req.httpBody = body
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let parts = uploadUrl.components(separatedBy: "/")
        let accountHash = parts.count > 3 ? parts[3] : ""
        return "https://imagedelivery.net/\(accountHash)/\(imageId)/public"
    }

    func updateTextItem(chapterId: String, itemId: String, content: String) async {
        do {
            // 서버가 strip 후 빈 문자열 거부(400) — addTextItem과 동일하게 U+200B로 fallback
            let safe = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "\u{200B}"
                : content
            let req = TextItemUpdateRequest(textContent: safe)
            let updated: ChapterItem = try await api.request("/chapters/\(chapterId)/texts/\(itemId)", method: "PUT", body: req)
            if var items = itemsByChapter[chapterId], let idx = items.firstIndex(where: { $0.id == itemId }) {
                items[idx] = updated
                itemsByChapter[chapterId] = items
            }
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func deleteItem(chapterId: String, itemId: String) async {
        do {
            try await api.requestVoid("/chapters/\(chapterId)/items/\(itemId)", method: "DELETE")
            itemsByChapter[chapterId]?.removeAll { $0.id == itemId }
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func moveToBlock(chapterId: String, itemId: String, targetBlockId: String) async {
        do {
            let req = MoveToBlockRequest(itemId: itemId, targetBlockId: targetBlockId)
            try await api.requestVoid("/chapters/\(chapterId)/items/move-to-block", method: "PUT", body: req)
            await loadItems(for: chapterId)
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func reorderBlock(chapterId: String, blockId: String, itemIds: [String]) async {
        do {
            let req = BlockReorderRequest(itemIds: itemIds)
            try await api.requestVoid("/chapters/\(chapterId)/blocks/\(blockId)/reorder", method: "PUT", body: req)
            await loadItems(for: chapterId)
        } catch let err as APIError {
            errorMessage = err.errorDescription
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
        } catch let err as APIError {
            errorMessage = err.errorDescription
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
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func cancelSideBySide(chapterId: String, textItemId: String) async {
        struct Body: Encodable { let textItemId: String }
        do {
            try await api.requestVoid("/chapters/\(chapterId)/side-by-side/cancel", method: "PUT",
                body: Body(textItemId: textItemId))
            await reloadAllItems()
        } catch let err as APIError {
            errorMessage = err.errorDescription
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
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }
}
