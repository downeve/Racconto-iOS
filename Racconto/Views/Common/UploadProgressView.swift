import SwiftUI

struct UploadProgressView: View {
    let pendingCount: Int
    let isUploading: Bool
    let hasFailed: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isUploading {
                ProgressView()
                    .scaleEffect(0.8)
                Text("업로드 중...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if hasFailed {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("업로드 실패")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("재시도") {
                    Task { await UploadService.shared.retryFailed() }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            } else {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(pendingCount)개 대기 중")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}
