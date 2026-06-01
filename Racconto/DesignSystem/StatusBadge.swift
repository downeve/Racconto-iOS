import SwiftUI

/// 프로젝트 상태 뱃지 (PART D-3 F1).
///
/// `.yellow`/`.purple`/raw color 직접 사용 금지 — 본 컴포넌트가 단일 출처.
/// 웹 `StatusBadge.tsx`와 동일 의미 매핑.
struct StatusBadge: View {
    let status: Project.ProjectStatus

    private var label: String {
        switch status {
        case .inProgress: return "진행 중"
        case .completed:  return "완료"
        case .published:  return "공개"
        case .archived:   return "보관"
        }
    }

    private var background: Color {
        switch status {
        case .inProgress: return .rcBadgeProgressBG
        case .completed:  return .rcBadgeDoneBG
        case .published:  return .rcBadgePublishedBG
        case .archived:   return .rcBadgeArchivedBG
        }
    }

    private var foreground: Color {
        switch status {
        case .inProgress: return .rcBadgeProgressFG
        case .completed:  return .rcBadgeDoneFG
        case .published:  return .rcBadgePublishedFG
        case .archived:   return .rcBadgeArchivedFG
        }
    }

    var body: some View {
        Text(label)
            .font(RType.eyebrow)
            .tracking(0.9)
            .textCase(.uppercase)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
            .accessibilityLabel(Text("상태: \(label)"))
    }
}
