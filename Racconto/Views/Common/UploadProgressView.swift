import SwiftUI

struct UploadProgressView: View {
    let pendingCount: Int
    let isUploading: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isUploading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(isUploading ? "업로드 중..." : "\(pendingCount)개 대기 중")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}
