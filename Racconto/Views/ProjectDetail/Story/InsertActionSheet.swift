import SwiftUI

struct InsertActionSheet: View {
    @Binding var isPresented: Bool
    let onSelect: (InsertKind) -> Void

    enum InsertKind {
        case text, photo, sideBySide, chapter, subChapter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("추가")
                .font(.system(.title2, design: .serif))
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

            ForEach(Array(rows.enumerated()), id: \.element.label) { idx, row in
                Button {
                    onSelect(row.kind)
                    isPresented = false
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: row.icon)
                            .font(.system(size: 17))
                            .frame(width: 38, height: 38)
                            .background(row.emphasized ? Color.primary : Color(.tertiarySystemBackground))
                            .foregroundStyle(row.emphasized ? Color(.systemBackground) : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.label)
                                .font(.system(.body, design: .serif))
                                .foregroundStyle(.primary)
                            Text(row.desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                if idx < rows.count - 1 {
                    Divider().padding(.leading, 70)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.bottom, 16)
        .presentationDetents([.height(440)])
        .presentationDragIndicator(.visible)
    }

    private var rows: [(kind: InsertKind, icon: String, label: String, desc: String, emphasized: Bool)] {
        [
            (.text,       "doc.text",            "텍스트",    "단락을 작성합니다",        true),
            (.photo,      "photo",               "사진 블록", "라이브러리에서 선택",      false),
            (.sideBySide, "rectangle.split.2x1", "나란히 배치", "사진 + 텍스트 한 쌍",  false),
            (.chapter,    "book.closed",         "챕터",      "새 최상위 챕터",          false),
            (.subChapter, "text.append",         "서브챕터",  "현재 챕터 아래에 추가",   false),
        ]
    }
}
