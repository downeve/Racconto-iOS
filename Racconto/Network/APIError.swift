import Foundation

enum APIError: LocalizedError {
    case unauthorized
    case limitExceeded(String)
    case notFound
    case serverError(Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "로그인이 필요합니다."
        case .limitExceeded(let msg):
            return msg
        case .notFound:
            return "요청한 항목을 찾을 수 없습니다."
        case .serverError(let code):
            return "서버 오류 (\(code))"
        case .decodingError(let err):
            return "데이터 오류: \(err.localizedDescription)"
        }
    }
}
