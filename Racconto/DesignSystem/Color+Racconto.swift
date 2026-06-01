import SwiftUI

/// Racconto 디자인 토큰 (PART D-1).
///
/// **단일 출처**: Asset Catalog의 `rc*.colorset` (Light/Dark Appearance 자동 전환).
/// 코드에서 raw `Color(red:green:blue:)`나 `.red`/`.yellow` 등 시스템 컬러를 직접
/// 쓰지 말고 이 토큰만 참조한다. 웹의 `tailwind.config.js` 토큰과 의미·값 일치.
///
/// - 다크모드는 시스템 ColorScheme + Asset Catalog Dark appearance로 자동 전환.
///   토큰 자체가 두 값을 갖기 때문에 `.environment(\.colorScheme)` 분기 없이도
///   F7(다크에서 accent 증발)이 구조적으로 발생하지 않는다.
extension Color {
    // MARK: Surfaces / Lines
    /// 페이지 배경. 웹 `canvas` (#F4EFE7) / `d-bg` (#16100C).
    static let rcCanvas  = Color("rcCanvas")
    /// 카드·시트 배경. 웹 `card` / `d-surface`.
    static let rcSurface = Color("rcSurface")
    /// 구분선·보더. 웹 `hair` / `d-line`.
    static let rcLine    = Color("rcLine")

    // MARK: Text
    /// 제목·본문 강조. 웹 `ink` / `d-hair`.
    static let rcInk     = Color("rcInk")
    /// 본문. 웹 `ink-2` / `d-soft`.
    static let rcInk2    = Color("rcInk2")
    /// 보조 텍스트. AA 보정값(웹 oklch 0.50). 웹 `muted` / `d-soft`.
    static let rcMuted   = Color("rcMuted")
    /// 메타·placeholder/disabled (장식 전용, AA 예외).
    static let rcFaint   = Color("rcFaint")

    // MARK: Semantics
    /// 링크·챕터 숫자·진행바. 웹 warm `accent` / `d-accent`.
    static let rcAccent  = Color("rcAccent")
    /// 파괴적 동작(삭제·되돌릴 수 없는 액션).
    static let rcDanger  = Color("rcDanger")
    /// 성공·확인.
    static let rcOk      = Color("rcOk")
    /// 경고.
    static let rcWarn    = Color("rcWarn")
    /// 라이트박스 배경 (#090503 @ 0.98).
    static let rcScrim   = Color("rcScrim")

    // MARK: Photo Color Labels (단일 매핑 — PhotoLabel enum 참조)
    static let rcLabelRed    = Color("rcLabelRed")
    static let rcLabelYellow = Color("rcLabelYellow")
    static let rcLabelGreen  = Color("rcLabelGreen")
    static let rcLabelBlue   = Color("rcLabelBlue")
    static let rcLabelPurple = Color("rcLabelPurple")

    // MARK: Status Badge
    /// 진행 중 — 따뜻한 살구색 배경 + 짙은 갈색 텍스트 (대비 5.4:1).
    static let rcBadgeProgressBG = Color("rcBadgeProgressBG")
    static let rcBadgeProgressFG = Color("rcBadgeProgressFG")
    /// 완료 — 옅은 민트 배경 + 짙은 초록 텍스트 (6.7:1).
    static let rcBadgeDoneBG     = Color("rcBadgeDoneBG")
    static let rcBadgeDoneFG     = Color("rcBadgeDoneFG")
    /// 공개 — 진한 ink 배경 + canvas 텍스트 (16:1). 토큰 재사용.
    static var rcBadgePublishedBG: Color { rcInk }
    static var rcBadgePublishedFG: Color { rcCanvas }
    /// 보관 — 옅은 stone 배경 + muted 텍스트 (4.6:1). fg는 토큰 재사용.
    static let rcBadgeArchivedBG = Color("rcBadgeArchivedBG")
    static var rcBadgeArchivedFG: Color { rcMuted }
}
