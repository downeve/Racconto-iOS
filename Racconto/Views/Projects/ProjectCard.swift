import SwiftUI

struct ProjectGridCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CachedImage(url: project.coverImageUrl, variant: .grid, contentMode: .fill)
                .aspectRatio(2/3, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .background(
                    Color(.tertiarySystemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(project.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                StatusBadge(status: project.status)

                if let location = project.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

struct StatusBadge: View {
    let status: Project.ProjectStatus

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case .inProgress: return "진행 중"
        case .completed:  return "완료"
        case .published:  return "게시됨"
        case .archived:   return "보관됨"
        }
    }

    private var color: Color {
        switch status {
        case .inProgress: return .purple
        case .completed:  return .green
        case .published:  return .blue
        case .archived:   return .gray
        }
    }
}
