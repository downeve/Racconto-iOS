import Foundation
import SwiftUI

@MainActor
@Observable
class ProjectListViewModel {
    var projects: [Project] = []
    var isLoading = false
    var errorMessage: String?

    private let api = RaccontoAPI.shared

    init() {
        // 프로젝트 메타데이터 변경 시 목록 갱신 (커버 설정, 제목 편집 등).
        NotificationCenter.default.addObserver(
            forName: .raccontoProjectUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.load() }
            }
        }
    }

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
                // 응답이 도착하는 사이 추가/삭제된 프로젝트(다른 경로) 분실 방지 — id 기준 머지.
                // 1) updated에 있는 id만 순서대로 채움 (서버 권위)
                // 2) updated에 없지만 로컬에 있는 id는 뒤에 append (방금 추가된 신규 프로젝트 등)
                let updatedIds = Set(updated.map(\.id))
                let extras = projects.filter { !updatedIds.contains($0.id) }
                projects = updated + extras
            } catch let err as APIError {
                errorMessage = err.errorDescription
            } catch {}
        }
    }
}
