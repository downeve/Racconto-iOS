import Foundation

@MainActor
@Observable
class PortfolioViewModel {
    var portfolio: PortfolioResponse?
    var isLoading = false
    var errorMessage: String?

    private let api = RaccontoAPI.shared

    func load(username: String) async {
        guard !username.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            portfolio = try await api.request("/portfolio/\(username)")
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
