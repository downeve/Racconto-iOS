import SwiftUI

struct ProjectCard: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            CachedImage(url: project.coverImageUrl, variant: .thumb, contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: Radius.panel))
                .background(Color(.tertiarySystemBackground).clipShape(RoundedRectangle(cornerRadius: Radius.panel)))

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

struct ProjectGridCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color(.tertiarySystemBackground)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    // cover variant: CF Dashboard에 정의된 프로젝트 커버 전용 crop
                    CachedImage(url: project.coverImageUrl, variant: .cover, contentMode: .fill)
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.large))

            VStack(alignment: .leading, spacing: 3) {
                ZStack(alignment: .topLeading) {
                    Text("가\n가")
                        .font(.subheadline)
                        .hidden()
                    Text(project.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                StatusBadge(status: project.status)

                if let location = project.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Label("placeholder", systemImage: "mappin")
                        .font(.caption2)
                        .hidden()
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// StatusBadge 정의는 DesignSystem/StatusBadge.swift 단일 출처.
// 이전에 inline `.purple/.green/.blue/.gray` raw 색 버전이 여기 있었으나,
// PART D-3 옵션 C 단일 컴포넌트화로 제거. 위의 ProjectCard/ProjectGridCard가
// 그 컴포넌트를 그대로 사용한다.
