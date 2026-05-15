import SwiftUI

struct StoryTabView: View {
    let project: Project
    var viewModel: StoryViewModel
    @State private var showOutline = false
    @State private var showPreview = false
    @State private var showInsert = false
    @State private var showAddChapter = false
    @State private var showAddSub = false
    @State private var isSelecting = false
    @State private var selectedItemIds: Set<String> = []
    @State private var showDeleteConfirm = false
    @State private var showLayoutAlert = false
    @State private var showAttachAlert = false
    @State private var showPhotoPicker = false
    @State private var showSideBySideAlert = false
    @State private var sideBySideBlock: Block? = nil
    @State private var showNewTextEditor = false

    var body: some View {
        content
            .task { if viewModel.chapters.isEmpty { await viewModel.load(projectId: project.id) } }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !isSelecting {
                        Button { showOutline = true } label: {
                            Image(systemName: "list.bullet")
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    if isSelecting {
                        Text(selectedItemIds.isEmpty ? "항목 선택" : "\(selectedItemIds.count)개 선택")
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelecting {
                        Button("취소") {
                            isSelecting = false
                            selectedItemIds.removeAll()
                        }
                    } else {
                        HStack(spacing: 16) {
                            Button("선택") { isSelecting = true }
                            Button(showPreview ? "편집" : "미리보기") { showPreview.toggle() }
                        }
                    }
                }
            }
            .sheet(isPresented: $showOutline) {
                ChapterOutlineSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showInsert) {
                InsertActionSheet(isPresented: $showInsert) { kind in
                    handleInsert(kind)
                }
            }
            .sheet(isPresented: $showAddChapter) {
                ChapterFormSheet(title: "새 챕터", confirmLabel: "생성") { title, desc in
                    Task {
                        await viewModel.createChapter(title: title, description: desc.isEmpty ? nil : desc)
                        // 새로 만든 챕터를 자동 expand
                        viewModel.expandedChapterId = viewModel.chapterTree.last?.parent.id
                    }
                }
            }
            .sheet(isPresented: $showAddSub) {
                ChapterFormSheet(title: "서브챕터 추가", confirmLabel: "생성") { title, desc in
                    Task {
                        await viewModel.createChapter(
                            title: title,
                            description: desc.isEmpty ? nil : desc,
                            parentId: viewModel.expandedChapterId
                        )
                    }
                }
            }
            .sheet(isPresented: $showNewTextEditor) {
                if let chapterId = viewModel.expandedChapterId {
                    TextBlockEditorView(block: nil, chapterId: chapterId, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPicker { items in
                    guard let chapterId = viewModel.expandedChapterId else { return }
                    Task { await viewModel.addPhotosToChapter(images: items, chapterId: chapterId) }
                }
            }
            .sheet(item: $sideBySideBlock) { block in
                if let chapterId = viewModel.expandedChapterId {
                    SideBySideSetupSheet(block: block, chapterId: chapterId, viewModel: viewModel)
                }
            }
            .alert("나란히 배치", isPresented: $showSideBySideAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("나란히 배치하려면 사진 블록과 텍스트 블록이 모두 필요합니다. 먼저 각 블록을 추가한 뒤 블록 메뉴(···)에서 설정하세요.")
            }
            .alert("오류", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("확인") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }

    private var content: some View {
        ZStack(alignment: .bottomTrailing) {
            if viewModel.isLoading && viewModel.chapters.isEmpty {
                ProgressView()
            } else if viewModel.chapterTree.isEmpty {
                ContentUnavailableView(
                    "챕터가 없습니다",
                    systemImage: "text.book.closed",
                    description: Text("우하단 + 버튼으로 첫 챕터를 추가하세요")
                )
            } else if showPreview {
                StoryPreviewView(viewModel: viewModel, projectId: project.id)
            } else {
                ChapterStackView(
                    viewModel: viewModel,
                    project: project,
                    isSelecting: $isSelecting,
                    selectedItemIds: $selectedItemIds
                )
            }

            if !showPreview && !isSelecting { fab }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting && !selectedItemIds.isEmpty {
                SelectModeBar(
                    count: selectedItemIds.count,
                    onMove: { },
                    onLayout: { showLayoutAlert = true },
                    onAttach: { showAttachAlert = true },
                    onDelete: { showDeleteConfirm = true }
                )
            }
        }
        .confirmationDialog(
            "\(selectedItemIds.count)개 사진을 삭제하시겠습니까?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                let ids = selectedItemIds
                selectedItemIds.removeAll()
                isSelecting = false
                Task {
                    guard let chapterId = viewModel.expandedChapterId else { return }
                    for id in ids {
                        await viewModel.deleteItem(chapterId: chapterId, itemId: id)
                    }
                }
            }
            Button("취소", role: .cancel) { }
        }
        .alert("레이아웃 변경", isPresented: $showLayoutAlert) {
            Button("취소", role: .cancel) { }
        } message: {
            Text("블록 에디터에서 레이아웃을 변경하세요.")
        }
        .alert("나란히 배치", isPresented: $showAttachAlert) {
            Button("취소", role: .cancel) { }
        } message: {
            Text("블록 에디터에서 나란히 배치를 설정하세요.")
        }
    }

    private var fab: some View {
        Button {
            showInsert = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .medium))
                .frame(width: 56, height: 56)
                .background(Color.primary)
                .foregroundStyle(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        }
        .padding(.trailing, 18)
        .padding(.bottom, 24)
    }

    private func handleInsert(_ kind: InsertActionSheet.InsertKind) {
        guard let currentId = viewModel.expandedChapterId else { return }
        switch kind {
        case .text:
            showNewTextEditor = true
        case .photo:
            showPhotoPicker = true
        case .sideBySide:
            let blocks = viewModel.blocks(for: currentId)
            let photoBlock = blocks.first { !$0.isSideBySide && !$0.photoItems.isEmpty }
            let hasText = blocks.contains { !$0.isSideBySide && $0.textItem != nil }
            if let block = photoBlock, hasText {
                sideBySideBlock = block
            } else {
                showSideBySideAlert = true
            }
        case .chapter:
            showAddChapter = true
        case .subChapter:
            showAddSub = true
        }
    }
}
