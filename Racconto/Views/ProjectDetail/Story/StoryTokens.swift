import SwiftUI

// MARK: - Color Tokens
//
// PART D-1 흡수: 모든 색 토큰을 rc* (Color+Racconto.swift) 로 위임.
// 기존 Story* Color Set은 호환을 위해 Asset Catalog에 남겨두지만, 신규 코드는
// 직접 `Color.rc*` 사용 권장. 본 enum은 기존 사용처와의 마이그레이션 브리지.

enum StoryTokens {
    // Surfaces
    static let paper      = Color.rcCanvas    // (구) StoryPaper #FBFAF7
    static let paper2     = Color.rcCanvas    // (구) StoryPaper2 — 동일 톤으로 흡수
    static let paper3     = Color.rcLine      // (구) StoryPaper3 — 더 어두운 면 → line으로

    // Ink
    static let ink        = Color.rcInk
    static let inkSoft    = Color.rcInk2
    static let muted      = Color.rcMuted     // 웹 AA 보정값(P0-1) 반영
    static let faint      = Color.rcFaint

    // Lines
    static let line       = Color.rcLine
    static let lineStrong = Color.rcMuted     // 더 진한 hairline — muted opacity로 표현해도 됨

    // Accents — README 옵션 A: brick 폐기, warm tan으로 단일화
    static let accent     = Color.rcAccent    // (구) StoryAccent brick #A8431F → warm tan #885531
    static let danger     = Color.rcDanger

    // Spacing
    static let blockGap: CGFloat   = 12    // ChapterStackView spacing 과 일치
    static let blockPadH: CGFloat  = 14
    static let blockPadV: CGFloat  = 10
    static let photoGap: CGFloat   = 4
    static let photoRadius: CGFloat = Radius.btn
}

// MARK: - Markdown Preprocessing
//
// preprocessMarkdown은 MarkdownUI의 CommonMark flanking 한계를 회피하던 ZWNJ 삽입 유틸이었으나,
// `Utils/MarkdownInline.swift` (Text + AttributedString 자체 렌더)로 전환되면서 사용처 없음.
// 향후 MarkdownUI를 다시 쓰게 되면 git 이력에서 복원.

// MARK: - Font Tokens

extension Font {
    /// 모노스페이스 eyebrow — 10pt, tracking 1.4 별도 적용
    static let storyEyebrow = Font.system(size: 10, weight: .medium, design: .monospaced)

    /// 본문 세리프 — 웹 text-body(15px, Georgia fallback)에 맞춤
    static let storyBodySerif = Font.custom("Georgia", size: 15)

    /// 블록 메타 — 모노스페이스 11pt
    static let storyBlockMeta = Font.system(size: 11, weight: .medium, design: .monospaced)
}
