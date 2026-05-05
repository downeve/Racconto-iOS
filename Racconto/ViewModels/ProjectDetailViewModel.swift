import Foundation

@Observable
class ProjectDetailViewModel {
    var project: Project
    var errorMessage: String?

    private let api = RaccontoAPI.shared

    init(project: Project) {
        self.project = project
    }

    func update(_ req: ProjectUpdateRequest) async {
        do {
            let updated: Project = try await api.request("/projects/\(project.id)", method: "PUT", body: req)
            project = updated
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }
}
