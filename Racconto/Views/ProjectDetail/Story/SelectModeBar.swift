import SwiftUI

struct SelectModeBar: View {
    let count: Int
    var onMove: () -> Void
    var onLayout: () -> Void
    var onAttach: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            actionItem("square.on.square",    label: "이동",    action: onMove)
            actionItem("rectangle.split.3x1", label: "레이아웃", action: onLayout)
            actionItem("rectangle.split.2x1", label: "나란히",   action: onAttach)
            actionItem("trash",               label: "삭제",    color: .red, action: onDelete)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.quaternary))
        .shadow(color: .black.opacity(0.08), radius: 24, y: 8)
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }

    private func actionItem(_ icon: String, label: String, color: Color = .accentColor, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 19))
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }
}
