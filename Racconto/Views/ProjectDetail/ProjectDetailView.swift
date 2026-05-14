import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @State private var selectedTab = 0
    @State private var photosVM = PhotosViewModel()
    @State private var storyVM = StoryViewModel()
    @State private var notesVM = NotesViewModel()
    @State private var detailVM: ProjectDetailViewModel
    @State private var showEdit = false

    init(project: Project) {
        self.project = project
        _detailVM = State(wrappedValue: ProjectDetailViewModel(project: project))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("탭", selection: $selectedTab) {
                Text("사진").tag(0)
                Text("스토리").tag(1)
                Text("노트").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            switch selectedTab {
            case 0:
                PhotosTabView(project: detailVM.project, viewModel: photosVM)
            case 1:
                StoryTabView(project: detailVM.project, viewModel: storyVM)
            case 2:
                NotesTabView(project: detailVM.project, viewModel: notesVM)
            default:
                EmptyView()
            }
        }
        .navigationTitle(detailVM.project.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEdit = true } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            ProjectEditSheet(project: detailVM.project) { req in
                Task { await detailVM.update(req) }
            }
        }
        .alert("오류", isPresented: Binding(
            get: { detailVM.errorMessage != nil },
            set: { if !$0 { detailVM.errorMessage = nil } }
        )) {
            Button("확인") { detailVM.errorMessage = nil }
        } message: {
            Text(detailVM.errorMessage ?? "")
        }
        .task {
            await photosVM.load(projectId: project.id)
        }
        .onChange(of: project.id) { _, newId in
            selectedTab = 0
            photosVM = PhotosViewModel()
            storyVM = StoryViewModel()
            notesVM = NotesViewModel()
            detailVM = ProjectDetailViewModel(project: project)
            Task { await photosVM.load(projectId: newId) }
        }
        .onChange(of: selectedTab) { _, tab in
            Task {
                switch tab {
                case 1:
                    if storyVM.chapters.isEmpty { await storyVM.load(projectId: project.id) }
                    else { await storyVM.reloadAllItems() }
                case 2: if notesVM.notes.isEmpty { await notesVM.load(projectId: project.id) }
                default: break
                }
            }
        }
    }
}

// MARK: - ProjectEditSheet

struct ProjectEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project
    let onSave: (ProjectUpdateRequest) -> Void

    @State private var title: String
    @State private var description: String
    @State private var location: String
    @State private var status: Project.ProjectStatus
    @State private var isPublic: Bool

    init(project: Project, onSave: @escaping (ProjectUpdateRequest) -> Void) {
        self.project = project
        self.onSave = onSave
        _title       = State(initialValue: project.title)
        _description = State(initialValue: project.description ?? "")
        _location    = State(initialValue: project.location ?? "")
        _status      = State(initialValue: project.status)
        _isPublic    = State(initialValue: project.isPublic == "true")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("제목").font(.caption).foregroundStyle(.secondary)
                        TextField("프로젝트 제목", text: $title)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("설명").font(.caption).foregroundStyle(.secondary)
                        TextField("프로젝트 설명", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("촬영 장소").font(.caption).foregroundStyle(.secondary)
                        TextField("장소 입력", text: $location)
                    }
                }
                Section("설정") {
                    Picker("진행 상태", selection: $status) {
                        Text("진행 중").tag(Project.ProjectStatus.inProgress)
                        Text("완료").tag(Project.ProjectStatus.completed)
                        Text("게시됨").tag(Project.ProjectStatus.published)
                        Text("보관됨").tag(Project.ProjectStatus.archived)
                    }
                    Toggle("포트폴리오 공개", isOn: $isPublic)
                }
            }
            .navigationTitle("프로젝트 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let req = ProjectUpdateRequest(
                            title: title.trimmingCharacters(in: .whitespaces),
                            description: description.isEmpty ? nil : description,
                            status: status.rawValue,
                            location: location.isEmpty ? nil : location,
                            isPublic: isPublic ? "true" : "false"
                        )
                        onSave(req)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
