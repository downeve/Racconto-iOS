import SwiftUI

/// 블록 카드 공용 헤더/hairline 모디파이어.
/// - iPhone: eyebrow + trailing eyebrow 만 표시, 버튼 없음 (롱프레스 → contextMenu)
/// - iPad:   eyebrow + trailing eyebrow + ▲▼⋯ 버튼 표시
struct BlockCardChrome: ViewModifier {
    let leadingEyebrow: String          // ex) "Photographs · № 06"
    var trailingEyebrow: String? = nil  // ex) "grid" — accent 색으로 표시
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?
    let onMore: (() -> Void)?           // iPad 전용 ⋯ 메뉴 진입

    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Eyebrow(text: leadingEyebrow)
                if let trailing = trailingEyebrow {
                    Eyebrow(text: trailing, tone: StoryTokens.accent)
                }
                Spacer()
                // iPad 에서만 버튼 표시
                if sizeClass == .regular {
                    if let up = onMoveUp   { iconBtn("chevron.up",   action: up) }
                    if let dn = onMoveDown { iconBtn("chevron.down",  action: dn) }
                    if let more = onMore   { iconBtn("ellipsis",      action: more) }
                }
            }
            content
        }
        .padding(.horizontal, StoryTokens.blockPadH)
        .padding(.vertical, StoryTokens.blockPadV)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(StoryTokens.line)
                .frame(height: 0.5)
        }
    }

    private func iconBtn(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(StoryTokens.muted)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func blockCardChrome(
        leadingEyebrow: String,
        trailingEyebrow: String? = nil,
        onMoveUp: (() -> Void)? = nil,
        onMoveDown: (() -> Void)? = nil,
        onMore: (() -> Void)? = nil
    ) -> some View {
        modifier(BlockCardChrome(
            leadingEyebrow: leadingEyebrow,
            trailingEyebrow: trailingEyebrow,
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown,
            onMore: onMore
        ))
    }
}
