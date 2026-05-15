import SwiftUI

struct ReaderSettingsSheet: View {
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 20)

            Text("독자 설정")
                .font(.system(size: 15, weight: .semibold))

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
