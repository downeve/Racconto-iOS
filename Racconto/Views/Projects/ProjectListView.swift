import SwiftUI

struct ProjectListView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    var viewModel: ProjectListViewModel
    var selectedProject: Binding<Project?>?

    @State private var showForm = false
    @State private var isEditing = false
    @State private var deleteAlert: Project? = nil

    var body: some View {
        List {
            ForEach(viewModel.projects) { project in
                row(for: project)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteAlert = project
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .onMove { offsets, destination in
                viewModel.move(from: offsets, to: destination)
            }
        }
        .listStyle(.plain)
        .navigationTitle("프로젝트")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(isPresented: $showForm) {
            ProjectFormView(viewModel: viewModel)
        }
        .alert("프로젝트 삭제", isPresented: Binding(
            get: { deleteAlert != nil },
            set: { if !$0 { deleteAlert = nil } }
        )) {
            Button("삭제", role: .destructive) {
                if let p = deleteAlert {
                    Task { await viewModel.delete(id: p.id) }
                }
                deleteAlert = nil
            }
            Button("취소", role: .cancel) { deleteAlert = nil }
        } message: {
            let title = deleteAlert?.title ?? ""
            Text("'\(title)' 프로젝트를 삭제하시겠습니까?")
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

    @ViewBuilder
    private func row(for project: Project) -> some View {
        if sizeClass == .regular, let binding = selectedProject {
            // iPad: tap to select
            ProjectCard(project: project)
                .contentShape(Rectangle())
                .onTapGesture { binding.wrappedValue = project }
                .background(binding.wrappedValue?.id == project.id ? Color.accentColor.opacity(0.08) : Color.clear)
        } else {
            // iPhone: NavigationLink
            NavigationLink(destination: ProjectDetailView(project: project)) {
                ProjectCard(project: project)
            }
        }
    }
}
