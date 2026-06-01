import SwiftUI

/// Racconto 타이포 토큰 (PART D-2).
///
/// 웹 디자인 가이드 매핑:
/// - **UI/헤딩** = Pretendard (현재 미번들 → 시스템 기본 sans 폴백)
/// - **본문/에디토리얼 제목** = Noto Serif KR (현재 미번들 → Georgia 폴백)
///
/// 폰트 번들 추가 후 `serif(_:)` / `sans(_:)` 내부 한 줄 교체로 전환.
/// `relativeTo:`로 Dynamic Type 자동 연동.
///
/// 스케일 (웹 고정 스케일 매핑):
/// display 64 / h1 44 / h2 28 / h3 18 / body 15 / small 14 / menu 13 / caption 12 / eyebrow 11
enum RType {
    /// 본문/에디토리얼 — 현재 Georgia (Pretendard 변경 시 NotoSerifKR-Regular로 교체).
    static func serif(_ size: CGFloat, _ relativeTo: Font.TextStyle = .body) -> Font {
        .custom("Georgia", size: size, relativeTo: relativeTo)
    }

    /// UI/헤딩 — 시스템 sans (Pretendard 번들 후 "Pretendard-Regular"로 교체).
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular,
                     _ relativeTo: Font.TextStyle = .body) -> Font {
        .system(size: size, weight: weight).leading(.standard)
            // Dynamic Type 연동을 위해 .system 사용. 커스텀 폰트 적용 시:
            // .custom("Pretendard-Regular", size: size, relativeTo: relativeTo).weight(weight)
    }

    /// Mono eyebrow — 11pt, monospaced, medium. tracking 0.18·size는 호출 시 별도 적용.
    static var eyebrow: Font {
        .system(size: 11, weight: .medium, design: .monospaced)
    }

    // MARK: Semantic aliases (스케일 상수)
    static var display: Font { sans(64, weight: .semibold, .largeTitle) }
    static var h1:      Font { sans(44, weight: .semibold, .title) }
    static var h2:      Font { sans(28, weight: .semibold, .title2) }
    static var h3:      Font { sans(18, weight: .semibold, .title3) }
    static var body15:  Font { serif(15, .body) }
    static var small:   Font { sans(14, .callout) }
    static var menu:    Font { sans(13, .footnote) }
    static var caption: Font { sans(12, .caption) }
}

/// 모서리 반경 상수 (PART D-3 F6).
///
/// 사진은 0 (각진 프린트 무드), 버튼 2, 카드 3.
/// `large`(8)는 노트 카드처럼 시각적으로 더 둥근 카드용 — README spec 보강.
/// raw `cornerRadius`/`RoundedRectangle(cornerRadius:)` 사용 금지 — 이 enum 참조.
enum Radius {
    static let photo: CGFloat = 0
    static let btn:   CGFloat = 2
    static let card:  CGFloat = 3
    /// 4pt — 사진 grid 셀, 작은 thumbnail.
    static let cell:  CGFloat = 4
    /// 6pt — side-by-side 텍스트 박스 등.
    static let panel: CGFloat = 6
    /// 8pt — 노트 카드·EXIF 패널·composer 등 시각적으로 더 둥근 카드.
    static let large: CGFloat = 8
}
