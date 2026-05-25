import Foundation

@MainActor
@Observable
class ExploreViewModel {
    // 피드 상태
    var items: [ExploreItem] = []
    var cursor: String? = nil
    var hasMore: Bool = true
    var isLoading: Bool = false
    var cameraFilter: CameraType? = nil

    // 검색 상태
    var searchInput: String = ""
    var searchResults: ExploreSearchResponse? = nil
    var searchLoading: Bool = false

    var errorMessage: String? = nil

    /// 검색 query는 trim 후 2자 이상부터 활성.
    var isSearching: Bool {
        searchInput.trimmingCharacters(in: .whitespaces).count >= 2
    }

    private let api = RaccontoAPI.shared
    /// 검색 debounce용 — 입력 변경 시 이전 task 취소.
    private var searchDebounceTask: Task<Void, Never>? = nil

    // MARK: - Feed

    /// 카메라 필터 변경 시 호출. 기존 items 초기화 후 첫 페이지 fetch.
    func resetAndLoad(filter: CameraType?) async {
        cameraFilter = filter
        items = []
        cursor = nil
        hasMore = true
        await loadPage(reset: true)
    }

    /// 추가 페이지 로드 (무한 스크롤 sentinel에서 호출).
    func loadMoreIfNeeded() async {
        guard !isLoading, hasMore, cursor != nil, !isSearching else { return }
        await loadPage(reset: false)
    }

    private func loadPage(reset: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        var params: [String] = []
        if let cursor, !reset { params.append("cursor=\(cursor.urlEncoded)") }
        if let ct = cameraFilter { params.append("camera_type=\(ct.rawValue)") }
        let path = "/explore/feed" + (params.isEmpty ? "" : "?" + params.joined(separator: "&"))

        do {
            let resp: ExploreFeedResponse = try await api.request(path)
            if reset {
                items = resp.items
            } else {
                items.append(contentsOf: resp.items)
            }
            cursor = resp.nextCursor
            hasMore = resp.hasMore
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    // MARK: - Search

    /// onChange(of: searchInput)에서 호출. 300ms debounce.
    func onSearchInputChanged() {
        searchDebounceTask?.cancel()
        let trimmed = searchInput.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchResults = nil
            return
        }
        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.performSearch(query: trimmed)
        }
    }

    private func performSearch(query: String) async {
        searchLoading = true
        defer { searchLoading = false }
        do {
            let resp: ExploreSearchResponse = try await api.request(
                "/explore/search?q=\(query.urlEncoded)"
            )
            // 검색 중 입력이 또 바뀌었으면 무시
            guard isSearching, searchInput.trimmingCharacters(in: .whitespaces) == query else { return }
            searchResults = resp
        } catch {
            searchResults = ExploreSearchResponse(users: [], portfolios: [])
        }
    }

    func clearSearch() {
        searchInput = ""
        searchResults = nil
        searchDebounceTask?.cancel()
    }
}
