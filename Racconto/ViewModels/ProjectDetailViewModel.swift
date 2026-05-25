import Foundation

@MainActor
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
            // 목록 뷰가 변경된 메타데이터(제목/설명/장소/커버 등)를 반영하도록 브로드캐스트.
            NotificationCenter.default.post(
                name: .raccontoProjectUpdated,
                object: nil,
                userInfo: ["projectId": updated.id]
            )
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {}
    }
}
