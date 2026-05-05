import Foundation

enum CFVariant: String {
    case `public` = "public"   // 3200px — 라이트박스
    case grid = "grid"         // 800px  — 그리드 뷰
    case thumb = "thumb"       // 400px  — 카드 커버, 미리보기
}

func cfUrl(_ imageUrl: String?, variant: CFVariant = .public) -> URL? {
    guard let imageUrl, !imageUrl.isEmpty else { return nil }
    guard imageUrl.contains("imagedelivery.net") else { return URL(string: imageUrl) }
    let base = imageUrl.hasSuffix("/") ? String(imageUrl.dropLast()) : imageUrl
    let noVariant = base.components(separatedBy: "/").dropLast().joined(separator: "/")
    return URL(string: "\(noVariant)/\(variant.rawValue)")
}
