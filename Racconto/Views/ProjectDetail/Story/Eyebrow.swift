import SwiftUI

struct Eyebrow: View {
    let text: String
    var tone: Color = StoryTokens.muted

    var body: some View {
        Text(text.uppercased())
            .font(.storyEyebrow)
            .tracking(1.4)
            .foregroundStyle(tone)
    }
}
