import SwiftUI

struct ProjectFormView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: ProjectListViewModel

    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var status: Project.ProjectStatus = .inProgress
    @State private var isPublic = false

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("제목 *", text: $title)
                    TextField("설명", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("위치", text: $location)
                }
                Section("설정") {
                    Picker("상태", selection: $status) {
                        Text("진행 중").tag(Project.ProjectStatus.inProgress)
                        Text("완료").tag(Project.ProjectStatus.completed)
                        Text("게시됨").tag(Project.ProjectStatus.published)
                        Text("보관됨").tag(Project.ProjectStatus.archived)
                    }
                    Toggle("공개", isOn: $isPublic)
                }
            }
            .navigationTitle("새 프로젝트")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("생성") {
                        Task {
                            let req = ProjectCreateRequest(
                                title: title,
                                description: description.isEmpty ? nil : description,
                                status: status.rawValue,
                                location: location.isEmpty ? nil : location,
                                isPublic: isPublic ? "true" : "false"
                            )
                            await viewModel.create(req)
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
