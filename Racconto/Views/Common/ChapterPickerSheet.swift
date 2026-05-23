import SwiftUI

struct ChapterPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let projectId: String
    let onSelect: (Chapter, Set<String>) -> Void
    var photoId: String? = nil

    @State private var chapters: [Chapter] = []
    @State private var chapterNumbers: [String: String] = [:]
    @State private var addedChapterIds: Set<String> = []
    @State private var isLoading = false
    private let api = RaccontoAPI.shared

    // 시트 dismiss 후 다시 열릴 때 N+1 fetch 회피 (라이트박스에서 같은 사진 재진입 흔함)
    // 챕터 변경 시 invalidate 호출 필요.
    private static var membershipCache: [String: Set<String>] = [:]
    private static let cacheQueue = DispatchQueue(label: "racconto.chapterPicker.cache")

    static func invalidateMembershipCache(photoId: String) {
        cacheQueue.sync { _ = membershipCache.removeValue(forKey: photoId) }
    }

    static func invalidateAllMembershipCache() {
        cacheQueue.sync { membershipCache.removeAll() }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(chapters) { chapter in
                        Button {
                            onSelect(chapter, addedChapterIds)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                if chapter.parentId != nil {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    if let num = chapterNumbers[chapter.id] {
                                        Text("챕터 \(num)")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Text(chapter.title)
                                        .foregroundStyle(.primary)
                                }
                                Spacer()
                                if addedChapterIds.contains(chapter.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.body)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("챕터 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .task {
                isLoading = true
                defer { isLoading = false }

                guard let ch: [Chapter] = try? await api.request("/chapters/?project_id=\(projectId)") else { return }

                let tree = ChapterTreeBuilder.buildTree(ch)
                var numbers: [String: String] = [:]
                for (topIdx, node) in tree.enumerated() {
                    numbers[node.parent.id] = "\(topIdx + 1)"
                    for (subIdx, sub) in node.subs.enumerated() {
                        numbers[sub.id] = "\(topIdx + 1).\(subIdx + 1)"
                    }
                }
                chapters = tree.flatMap { node in [node.parent] + node.subs }
                chapterNumbers = numbers

                guard let pid = photoId else { return }

                // 캐시 hit 시 N+1 fetch 회피
                let cached = Self.cacheQueue.sync { Self.membershipCache[pid] }
                if let cached {
                    addedChapterIds = cached
                    return
                }

                // 백엔드 /photos/{id}/chapters — 단일 호출로 챕터 소속 조회 (P-1 근본 해결)
                let ids: [String] = (try? await api.request("/photos/\(pid)/chapters")) ?? []
                let found = Set(ids)
                addedChapterIds = found
                Self.cacheQueue.sync { Self.membershipCache[pid] = found }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
