import Foundation
import SwiftUI

@MainActor
@Observable
class ProjectListViewModel {
    var projects: [Project] = []
    var isLoading = false
    var errorMessage: String?

    private let api = RaccontoAPI.shared

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            projects = try await api.request("/projects/")
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch is CancellationError {
            // refreshable 취소 시 무시
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(_ req: ProjectCreateRequest) async {
        do {
            let project: Project = try await api.request("/projects/", method: "POST", body: req)
            projects.insert(project, at: 0)
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }

    func delete(id: String) async {
        projects.removeAll { $0.id == id }
        do {
            try await api.requestVoid("/projects/\(id)", method: "DELETE")
        } catch let err as APIError {
            errorMessage = err.errorDescription
            await load()
        } catch {}
    }

    func move(from offsets: IndexSet, to destination: Int) {
        projects.move(fromOffsets: offsets, toOffset: destination)
        let ids = projects.map(\.id)
        Task {
            do {
                let req = ProjectReorderRequest(projectIds: ids)
                let updated: [Project] = try await api.request("/projects/reorder", method: "PUT", body: req)
                projects = updated
            } catch {}
        }
    }
}
