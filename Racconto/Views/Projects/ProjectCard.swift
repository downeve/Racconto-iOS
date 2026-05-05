import SwiftUI

struct ProjectCard: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            CachedImage(url: project.coverImageUrl, variant: .thumb, contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    StatusBadge(status: project.status)
                    if let location = project.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
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
