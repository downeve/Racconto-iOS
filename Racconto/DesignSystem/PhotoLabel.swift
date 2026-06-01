import SwiftUI

/// 사진 컬러 라벨 단일 매핑 (PART D-3 F2).
///
/// `.red`/`.yellow` 등 시스템 컬러 직접 사용 금지 — 이 enum의 `color`만 참조.
/// rawValue는 서버 저장 형식(`"red"`/`"yellow"`/...)과 일치.
enum PhotoLabel: String, CaseIterable, Identifiable {
    case red, yellow, green, blue, purple

    var id: String { rawValue }

    /// SwiftUI Color — Asset Catalog `rcLabel*` 토큰.
    var color: Color {
        switch self {
        case .red:    return .rcLabelRed
        case .yellow: return .rcLabelYellow
        case .green:  return .rcLabelGreen
        case .blue:   return .rcLabelBlue
        case .purple: return .rcLabelPurple
        }
    }

    /// 한국어 기본 표시명 (사용자 설정의 사용자 정의 이름이 우선).
    var defaultName: String {
        switch self {
        case .red:    return "빨강"
        case .yellow: return "노랑"
        case .green:  return "초록"
        case .blue:   return "파랑"
        case .purple: return "보라"
        }
    }
}
