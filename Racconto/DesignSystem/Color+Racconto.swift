import SwiftUI

/// Racconto 디자인 토큰 (PART D-1).
///
/// **단일 출처**: Asset Catalog의 `rc*.colorset` (Light/Dark Appearance 자동 전환).
///
/// Xcode 15+ / 배포 타겟 iOS 17+ 이상에서는 **Asset Catalog Symbol Extension**이
/// Color Set 이름으로 `extension Color { static let rcCanvas: Color }` 같은 멤버를
/// **자동 합성**한다. 따라서 22개 토큰(rcCanvas/rcSurface/.../rcBadgeArchivedBG 등)은
/// 수동 정의 없이 그대로 `Color.rcCanvas` 형태로 참조 가능.
///
/// 본 파일은 **자동 합성되지 않는** 재사용 별칭만 정의:
/// - rcBadgePublishedBG/FG, rcBadgeArchivedFG는 기존 토큰 재사용이라 Asset Catalog에 없음.
///
/// - 다크모드는 시스템 ColorScheme + Asset Catalog Dark appearance로 자동 전환.
///   토큰 자체가 두 값을 갖기 때문에 `.environment(\.colorScheme)` 분기 없이도
///   F7(다크에서 accent 증발)이 구조적으로 발생하지 않는다.
extension Color {
    // MARK: Status Badge — 재사용 별칭 (Asset Catalog에 없음, 토큰 재사용)
    /// 공개 뱃지 배경 — rcInk 재사용.
    static var rcBadgePublishedBG: Color { rcInk }
    /// 공개 뱃지 텍스트 — rcCanvas 재사용.
    static var rcBadgePublishedFG: Color { rcCanvas }
    /// 보관 뱃지 텍스트 — rcMuted 재사용.
    static var rcBadgeArchivedFG: Color { rcMuted }
}
