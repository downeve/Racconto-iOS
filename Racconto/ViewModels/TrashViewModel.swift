import Foundation

@MainActor
@Observable
class TrashViewModel {
    struct PhotoGroup: Identifiable {
        let id: String          // projectId
        let projectTitle: String
        var photos: [Photo]
    }

    var deletedProjects: [Project] = []
    var photoGroups: [PhotoGroup] = []
    var isLoading = false
    var errorMessage: String?

    private let api = RaccontoAPI.shared

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let projTask: [Project] = api.request("/projects/trash")
            async let activeTask: [Project] = api.request("/projects/")
            async let photosTask: [Photo] = api.request("/photos/?include_deleted=true")

            let proj = try await projTask
            let active = try await activeTask
            let allPhotos = try await photosTask

            deletedProjects = proj

            let deletedProjectIds = Set(proj.map { $0.id })
            let deletedPhotos = allPhotos.filter { $0.deletedAt != nil && !deletedProjectIds.contains($0.projectId) }
            let projectMap = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0.title) })

            var groups: [String: PhotoGroup] = [:]
            for photo in deletedPhotos {
                let title = projectMap[photo.projectId] ?? "알 수 없는 프로젝트"
                if groups[photo.projectId] == nil {
                    groups[photo.projectId] = PhotoGroup(id: photo.projectId, projectTitle: title, photos: [])
                }
                groups[photo.projectId]!.photos.append(photo)
            }
            photoGroups = groups.values.sorted { $0.projectTitle < $1.projectTitle }
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func restoreProject(_ project: Project) async {
        do {
            try await api.requestVoid("/projects/\(project.id)/restore", method: "POST")
            deletedProjects.removeAll { $0.id == project.id }
        } catch let err as APIError { errorMessage = err.errorDescription } catch {}
    }

    func permanentDeleteProject(_ project: Project) async {
        do {
            try await api.requestVoid("/projects/\(project.id)/permanent", method: "DELETE")
            deletedProjects.removeAll { $0.id == project.id }
        } catch let err as APIError { errorMessage = err.errorDescription } catch {}
    }

    func restore(photo: Photo) async {
        do {
            let restored: Photo = try await api.request("/photos/\(photo.id)/restore", method: "POST")
            removePhoto(id: restored.id)
        } catch let err as APIError { errorMessage = err.errorDescription } catch {}
    }

    func permanentDelete(photo: Photo) async {
        do {
            try await api.requestVoid(
                "/photos/bulk-permanent", method: "DELETE",
                body: BulkPermanentDeleteRequest(photoIds: [photo.id])
            )
            removePhoto(id: photo.id)
        } catch let err as APIError { errorMessage = err.errorDescription } catch {}
    }

    private func removePhoto(id: String) {
        for i in photoGroups.indices {
            photoGroups[i].photos.removeAll { $0.id == id }
        }
        photoGroups.removeAll { $0.photos.isEmpty }
    }
}
