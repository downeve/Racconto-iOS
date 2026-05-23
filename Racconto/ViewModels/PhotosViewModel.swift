import Foundation

enum PhotoSortBy: String, CaseIterable {
    case `default`, takenAt, name
    var label: String {
        switch self {
        case .default: "업로드"
        case .takenAt: "촬영일순"
        case .name:    "파일명순"
        }
    }
}

enum PhotoSortOrder: String { case asc, desc }

@MainActor
@Observable
class PhotosViewModel {
    var photos: [Photo] = [] {
        didSet { recomputeFiltered() }
    }
    var isLoading = false
    var errorMessage: String?
    var ratingFilter: Int? = nil { didSet { recomputeFiltered() } }
    var colorFilter: String? = nil { didSet { recomputeFiltered() } }
    var folderFilter: String? = nil { didSet { recomputeFiltered() } }
    var sortBy: PhotoSortBy {
        didSet {
            UserDefaults.standard.set(sortBy.rawValue, forKey: "photo_sort_by")
            recomputeFiltered()
        }
    }
    var sortOrder: PhotoSortOrder {
        didSet {
            UserDefaults.standard.set(sortOrder.rawValue, forKey: "photo_sort_order")
            recomputeFiltered()
        }
    }

    init() {
        let savedSortBy = UserDefaults.standard.string(forKey: "photo_sort_by")
        sortBy = PhotoSortBy(rawValue: savedSortBy ?? "") ?? .default
        let savedSortOrder = UserDefaults.standard.string(forKey: "photo_sort_order")
        sortOrder = PhotoSortOrder(rawValue: savedSortOrder ?? "") ?? .asc
    }
    var isSelecting = false
    var selectedIds: Set<String> = []
    var columns = 2

    var folders: [String] {
        Array(Set(photos.compactMap(\.folder))).sorted()
    }

    /// 정렬·필터 결과 캐시. 의존 프로퍼티(photos, *Filter, sort*) didSet에서 갱신.
    /// 매 뷰 갱신마다 O(N log N) 재계산되던 computed property를 stored로 전환.
    private(set) var filteredPhotos: [Photo] = []

    private func recomputeFiltered() {
        var result = photos.filter { photo in
            if let r = ratingFilter, photo.rating != r { return false }
            if let c = colorFilter, photo.colorLabel != c { return false }
            if let f = folderFilter, photo.folder != f { return false }
            return true
        }
        switch sortBy {
        case .default:
            result.sort { sortOrder == .asc ? $0.order < $1.order : $0.order > $1.order }
        case .takenAt:
            result.sort {
                let a = $0.takenAt ?? .distantPast
                let b = $1.takenAt ?? .distantPast
                return sortOrder == .asc ? a < b : a > b
            }
        case .name:
            result.sort {
                let a = $0.originalFilename ?? ""
                let b = $1.originalFilename ?? ""
                return sortOrder == .asc ? a < b : a > b
            }
        }
        filteredPhotos = result
    }

    private let api = RaccontoAPI.shared
    private var currentProjectId: String = ""

    func load(projectId: String) async {
        currentProjectId = projectId
        isLoading = true
        defer { isLoading = false }
        do {
            let all: [Photo] = try await api.request("/photos/?project_id=\(projectId)")
            photos = all.filter { $0.deletedAt == nil }
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func updateRating(photoId: String, rating: Int) async {
        let prev = photos.first(where: { $0.id == photoId })?.rating
        if let idx = photos.firstIndex(where: { $0.id == photoId }) {
            photos[idx].rating = (prev == rating) ? nil : rating
        }
        let newRating = (prev == rating) ? nil : rating
        do {
            let req = PhotoUpdateRequest(rating: newRating)
            let updated: Photo = try await api.request("/photos/\(photoId)", method: "PUT", body: req)
            if let idx = photos.firstIndex(where: { $0.id == photoId }) { photos[idx] = updated }
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func updateColorLabel(photoId: String, label: String?) async {
        if let idx = photos.firstIndex(where: { $0.id == photoId }) { photos[idx].colorLabel = label }
        do {
            let req = PhotoUpdateRequest(colorLabel: label)
            let updated: Photo = try await api.request("/photos/\(photoId)", method: "PUT", body: req)
            if let idx = photos.firstIndex(where: { $0.id == photoId }) { photos[idx] = updated }
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func softDelete(photoId: String) async {
        photos.removeAll { $0.id == photoId }
        do {
            try await api.requestVoid("/photos/\(photoId)", method: "DELETE")
        } catch {
            // 실패 시 서버 상태와 동기화 — currentProjectId가 비어있으면 재로드 생략
            if !currentProjectId.isEmpty {
                await load(projectId: currentProjectId)
            }
        }
    }

    func rotate(photoId: String, angle: Int) async {
        do {
            struct RotateBody: Encodable { let angle: Int }
            let updated: Photo = try await api.request("/photos/\(photoId)/rotate", method: "POST", body: RotateBody(angle: angle))
            if let idx = photos.firstIndex(where: { $0.id == photoId }) { photos[idx] = updated }
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func addToChapter(photoIds: [String], chapterId: String) async {
        for photoId in photoIds {
            do {
                let req = PhotoItemAddRequest(photoId: photoId)
                try await api.requestVoid("/chapters/\(chapterId)/photos", method: "POST", body: req)
            } catch let err as APIError {
                errorMessage = err.errorDescription
            } catch {}
        }
    }

    func removeFromChapter(photoId: String, chapterId: String) async {
        do {
            try await api.requestVoid("/chapters/\(chapterId)/photos/\(photoId)", method: "DELETE")
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func setCoverImage(projectId: String, imageUrl: String) async {
        do {
            let req = ProjectUpdateRequest(coverImageUrl: imageUrl)
            try await api.requestVoid("/projects/\(projectId)", method: "PUT", body: req)
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func toggleSelection(_ id: String) {
        if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) }
    }

    func clearSelection() {
        selectedIds = []
        isSelecting = false
    }

    func append(_ photo: Photo) {
        photos.insert(photo, at: 0)
    }
}
