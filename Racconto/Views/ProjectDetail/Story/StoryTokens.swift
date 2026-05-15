import SwiftUI

// MARK: - Color Tokens

enum StoryTokens {
    // Surfaces — 따뜻한 페이퍼 톤. 다크모드에선 잉크 톤으로 반전.
    static let paper      = Color("StoryPaper")       // #FBFAF7 / dark: #1A1814
    static let paper2     = Color("StoryPaper2")      // #F4F2EC / dark: #232019
    static let paper3     = Color("StoryPaper3")      // #ECEAE2 / dark: #2C2823

    // Ink
    static let ink        = Color("StoryInk")         // #1F1B16 / dark: #F5F1E8
    static let inkSoft    = Color("StoryInkSoft")     // #3A342B / dark: #D8D0BE
    static let muted      = Color("StoryMuted")       // #7B7468
    static let faint      = Color("StoryFaint")       // #B8B1A4

    // Lines
    static let line       = Color("StoryLine")        // #E2DED4 / dark: #3A342B
    static let lineStrong = Color("StoryLineStrong")  // #C9C3B4 / dark: #4A4239

    // Accents
    static let accent     = Color("StoryAccent")      // #A8431F (muted brick)
    static let danger     = Color("StoryDanger")      // #B0322B

    // Spacing
    static let blockGap: CGFloat   = 12    // ChapterStackView spacing 과 일치
    static let blockPadH: CGFloat  = 14
    static let blockPadV: CGFloat  = 10
    static let photoGap: CGFloat   = 4
    static let photoRadius: CGFloat = 2
}

// MARK: - Markdown Preprocessing

/// CommonMark 규칙상 닫는 ** 또는 * 바로 앞에 구두점(:;,.!?)이 있으면
/// right-flanking delimiter 조건 불충족 → bold/italic 미적용.
/// 구두점을 마커 밖으로 이동해 렌더링을 강제한다.
/// 예) **올림푸스 Mju:** → **올림푸스 Mju**:
func preprocessMarkdown(_ text: String) -> String {
    let punctuation = "[:;,.!?]"
    var result = text

    // Bold: **text구두점** → **text**구두점
    if let boldPattern = try? NSRegularExpression(
        pattern: "\\*\\*(.+?)(\(punctuation)+)\\*\\*",
        options: [.dotMatchesLineSeparators]
    ) {
        result = boldPattern.stringByReplacingMatches(
            in: result,
            range: NSRange(result.startIndex..., in: result),
            withTemplate: "**$1**$2"
        )
    }

    // Italic: *text구두점* → *text*구두점 (** 는 제외)
    if let italicPattern = try? NSRegularExpression(
        pattern: "(?<!\\*)\\*(?!\\*)(.+?)(\(punctuation)+)\\*(?!\\*)",
        options: [.dotMatchesLineSeparators]
    ) {
        result = italicPattern.stringByReplacingMatches(
            in: result,
            range: NSRange(result.startIndex..., in: result),
            withTemplate: "*$1*$2"
        )
    }

    return result
}

// MARK: - Font Tokens

extension Font {
    /// 모노스페이스 eyebrow — 10pt, tracking 1.4 별도 적용
    static let storyEyebrow = Font.system(size: 10, weight: .medium, design: .monospaced)

    /// 본문 세리프 — 웹 text-body(15px, Georgia fallback)에 맞춤
    static let storyBodySerif = Font.custom("Georgia", size: 15)

    /// 블록 메타 — 모노스페이스 11pt
    static let storyBlockMeta = Font.system(size: 11, weight: .medium, design: .monospaced)
}
