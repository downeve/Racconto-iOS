import Foundation
import SwiftUI

enum CFVariant: String {
    case `public` = "public"           // 3200px — 원본/다운로드
    case lightbox = "lightbox"         // 2048px — iPad/데스크톱 라이트박스
    case lightboxmobile = "lightboxmobile" // 1600px — iPhone 라이트박스
    case grid = "grid"                 // 800px — 그리드 뷰
    case mobile = "mobile"             // 480px — 작은 셀
    case thumb = "thumb"               // 400px — 카드 커버, 미리보기
    case cover = "cover"               // 프로젝트/포트폴리오 커버 (crop ratio 적용)
}

func cfUrl(_ imageUrl: String?, variant: CFVariant = .public) -> URL? {
    guard let imageUrl, !imageUrl.isEmpty else { return nil }
    guard imageUrl.contains("imagedelivery.net") else { return URL(string: imageUrl) }
    let base = imageUrl.hasSuffix("/") ? String(imageUrl.dropLast()) : imageUrl
    let noVariant = base.components(separatedBy: "/").dropLast().joined(separator: "/")
    return URL(string: "\(noVariant)/\(variant.rawValue)")
}

/// 디바이스 sizeClass에 따라 적절한 lightbox variant 선택.
/// - iPhone(compact): `lightboxmobile`(1600px) — 약 191KB
/// - iPad/데스크톱(regular): `lightbox`(2048px) — 약 371KB
/// - nil(분기 불가): `lightbox` 기본값
func lightboxVariant(for sizeClass: UserInterfaceSizeClass?) -> CFVariant {
    sizeClass == .compact ? .lightboxmobile : .lightbox
}

/// `cfUrl(url, variant: lightboxVariant(for: sizeClass))` 단축.
func cfLightboxUrl(_ imageUrl: String?, sizeClass: UserInterfaceSizeClass?) -> URL? {
    cfUrl(imageUrl, variant: lightboxVariant(for: sizeClass))
}
