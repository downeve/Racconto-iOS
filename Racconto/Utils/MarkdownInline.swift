import Foundation
import SwiftUI

/// 인라인 마크다운(`**bold**`, `*italic*`, `***both***` 및 `_` 변형)을 `AttributedString`으로 변환.
///
/// MarkdownUI의 CommonMark flanking 규칙 한계 회피용 — 한글 등 비라틴 문자에 인접한 `***text***`가
/// 한 종류 emphasis만 적용되는 문제를 정규식 기반 직접 토큰화로 우회.
/// 웹의 `preprocessBoldItalic` (react-markdown + rehype-raw 경로)과 동일한 전략.
///
/// 처리:
/// - `***text***` / `___text___` → bold + italic
/// - `**text**`   / `__text__`   → bold
/// - `*text*`     / `_text_`     → italic
/// - 단일 `\n`은 hard break (SwiftUI Text의 기본 동작)
/// - 내부에 동일 마커 포함 시 매치 실패 (예: `**a*b**`는 그대로 표시)
///
/// 한계:
/// - 헤딩(`#`), 리스트(`- `), blockquote, code, link 미지원
/// - 스토리 텍스트 블록은 인라인 위주 사용이 전제
///
/// 사용:
/// ```
/// Text(MarkdownInline.attributed(content))
///     .font(.custom("Georgia", size: 15))
/// ```
/// `inlinePresentationIntent` 사용 → 외부 `.font(...)` 가 Georgia일 때 SwiftUI가 자동으로
/// Georgia-Bold / Georgia-Italic / Georgia-BoldItalic variant 선택.
enum MarkdownInline {
    static func attributed(_ text: String) -> AttributedString {
        var result = AttributedString()
        for segment in tokenize(text) {
            var part = AttributedString(segment.text)
            switch segment.style {
            case .plain:
                break
            case .bold:
                part.inlinePresentationIntent = .stronglyEmphasized
            case .italic:
                part.inlinePresentationIntent = .emphasized
            case .boldItalic:
                part.inlinePresentationIntent = [.stronglyEmphasized, .emphasized]
            }
            result.append(part)
        }
        return result
    }

    // MARK: - Tokenizer (file-private)

    private enum SegmentStyle {
        case plain, bold, italic, boldItalic
    }

    private struct Segment {
        let text: String
        let style: SegmentStyle
    }

    private struct EmphasisMatch {
        let content: String
        let style: SegmentStyle
        let end: String.Index
    }

    private static func tokenize(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        var plain = ""
        var i = text.startIndex

        while i < text.endIndex {
            if let match = matchEmphasis(in: text, at: i) {
                if !plain.isEmpty {
                    segments.append(Segment(text: plain, style: .plain))
                    plain = ""
                }
                segments.append(Segment(text: match.content, style: match.style))
                i = match.end
            } else {
                plain.append(text[i])
                i = text.index(after: i)
            }
        }
        if !plain.isEmpty {
            segments.append(Segment(text: plain, style: .plain))
        }
        return segments
    }

    /// 현 위치에서 가능한 가장 긴 emphasis 마커를 시도 (3 → 2 → 1, `*` → `_` 순).
    private static func matchEmphasis(in text: String, at start: String.Index) -> EmphasisMatch? {
        for marker: Character in ["*", "_"] {
            for length in [3, 2, 1] {
                if let m = tryMatch(in: text, at: start, marker: marker, length: length) {
                    return m
                }
            }
        }
        return nil
    }

    /// `start` 위치에서 `marker`가 정확히 `length`번 반복되는 opener를 찾고, 같은 길이의 closer를 매칭.
    /// 내용에 marker 1자라도 포함되면 매치 실패 (단순한 비중첩 정책).
    private static func tryMatch(
        in text: String,
        at start: String.Index,
        marker: Character,
        length: Int
    ) -> EmphasisMatch? {
        // 1) opener: marker × length, 그 다음 문자는 marker가 아니어야 함 (오버 매칭 방지)
        var idx = start
        for _ in 0..<length {
            guard idx < text.endIndex, text[idx] == marker else { return nil }
            idx = text.index(after: idx)
        }
        // opener 직후가 marker면 더 긴 마커 케이스이므로 우선순위에 따라 다음 라운드에서 처리됨.
        // 단 우리는 3→2→1 순으로 시도하므로 여기까지 왔다는 건 이미 3 시도 실패 후 2 또는 1.
        // 예: `****text**` → 4 stars opener. 3 시도 실패(content 없음), 2 시도 — opener 2개 + content `**text` + closer? content에 marker 있으므로 실패.
        if idx < text.endIndex && text[idx] == marker {
            return nil
        }

        let contentStart = idx
        // 2) closer 탐색 — 내용 중에 marker 등장 시 매치 실패
        while idx < text.endIndex {
            if text[idx] == marker {
                // closer 후보: marker × length 정확히
                var closerIdx = idx
                var run = 0
                while closerIdx < text.endIndex, text[closerIdx] == marker {
                    closerIdx = text.index(after: closerIdx)
                    run += 1
                    if run > length { break }
                }
                guard run == length else {
                    return nil // 마커 수 불일치 — 매치 실패
                }
                let content = String(text[contentStart..<idx])
                guard !content.isEmpty else { return nil }
                let style: SegmentStyle = {
                    switch length {
                    case 3: return .boldItalic
                    case 2: return .bold
                    default: return .italic
                    }
                }()
                return EmphasisMatch(content: content, style: style, end: closerIdx)
            }
            idx = text.index(after: idx)
        }
        return nil
    }
}
