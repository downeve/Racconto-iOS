import SwiftUI

struct SideBySideSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    let block: Block
    let chapterId: String
    var viewModel: StoryViewModel

    @State private var selectedBlockId: String? = nil
    @State private var position: String = "side-left"

    private var isSourcePhoto: Bool { !block.photoItems.isEmpty }

    private var counterpartBlocks: [Block] {
        viewModel.blocks(for: chapterId).filter { candidate in
            guard !candidate.isSideBySide, candidate.id != block.id else { return false }
            return isSourcePhoto ? candidate.textItem != nil : !candidate.photoItems.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(isSourcePhoto ? "결합할 텍스트 블록 선택" : "결합할 사진 블록 선택") {
                    if counterpartBlocks.isEmpty {
                        Text(isSourcePhoto ? "같은 챕터에 텍스트 블록이 없습니다" : "같은 챕터에 사진 블록이 없습니다")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(counterpartBlocks) { candidate in
                            Button {
                                selectedBlockId = candidate.id
                            } label: {
                                HStack {
                                    blockPreviewLabel(candidate)
                                    Spacer()
                                    if selectedBlockId == candidate.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("텍스트 위치") {
                    Picker("위치", selection: $position) {
                        Text("텍스트 왼쪽").tag("side-left")
                        Text("텍스트 오른쪽").tag("side-right")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .navigationTitle("나란히 배치")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("적용") {
                        guard let selectedId = selectedBlockId else { return }
                        let textItemId: String
                        let photoBlockId: String
                        if isSourcePhoto {
                            photoBlockId = block.id
                            textItemId = counterpartBlocks.first(where: { $0.id == selectedId })?.textItem?.id ?? ""
                        } else {
                            textItemId = block.textItem?.id ?? ""
                            photoBlockId = selectedId
                        }
                        guard !textItemId.isEmpty, !photoBlockId.isEmpty else { return }
                        Task {
                            await viewModel.setSideBySide(
                                chapterId: chapterId,
                                textItemId: textItemId,
                                photoBlockId: photoBlockId,
                                position: position
                            )
                            dismiss()
                        }
                    }
                    .disabled(selectedBlockId == nil)
                }
            }
        }
    }

    @ViewBuilder
    private func blockPreviewLabel(_ candidate: Block) -> some View {
        if let text = candidate.textItem?.textContent {
            Text(text.isEmpty ? "(빈 텍스트)" : text)
                .lineLimit(2)
                .font(.subheadline)
                .foregroundStyle(text.isEmpty ? .tertiary : .primary)
        } else if let url = candidate.firstImageUrl {
            HStack(spacing: 8) {
                CachedImage(url: url, variant: .thumb, contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipped()
                    .cornerRadius(Radius.cell)
                Text("사진 \(candidate.photoItems.count)장")
                    .font(.subheadline)
            }
        }
    }
}
