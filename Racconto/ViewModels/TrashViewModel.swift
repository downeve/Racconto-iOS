import Foundation

@Observable
class TrashViewModel {
    var photos: [Photo] = []
    var isLoading = false
    var errorMessage: String?

    private let api = RaccontoAPI.shared

    var deletedPhotos: [Photo] { photos.filter { $0.deletedAt != nil } }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let all: [Photo] = try await api.request("/photos/?include_deleted=true")
            photos = all.filter { $0.deletedAt != nil }
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore(photo: Photo) async {
        guard let filename = photo.originalFilename else { return }
        do {
            struct RestoreRequest: Encodable { let originalFilename: String }
            let restored: Photo = try await api.request(
                "/photos/restore-by-filename",
                method: "POST",
                body: RestoreRequest(originalFilename: filename)
            )
            photos.removeAll { $0.id == restored.id }
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func permanentDelete(photo: Photo) async {
        do {
            try await api.requestVoid(
                "/photos/bulk-permanent",
                method: "DELETE",
                body: BulkPermanentDeleteRequest(photoIds: [photo.id])
            )
            photos.removeAll { $0.id == photo.id }
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }
}
