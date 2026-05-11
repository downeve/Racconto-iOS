import SwiftUI

struct ProjectListView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    var viewModel: ProjectListViewModel
    var selectedProject: Binding<Project?>?

    @State private var showForm = false
    @State private var deleteAlert: Project? = nil

    private func columnCount(for width: CGFloat) -> Int {
        if width < 600 { return 2 }
        if width < 1000 { return 3 }
        return 4
    }

    var body: some View {
        GeometryReader { geo in
            let cols = columnCount(for: geo.size.width)
            let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: cols)

            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(viewModel.projects) { project in
                        cell(for: project)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteAlert = project
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(12)
            }
            .refreshable { await viewModel.load() }
        }
        .navigationTitle("프로젝트")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showForm = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
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
    private func cell(for project: Project) -> some View {
        if sizeClass == .regular, let binding = selectedProject {
            ProjectGridCard(project: project)
                .contentShape(Rectangle())
                .onTapGesture { binding.wrappedValue = project }
                .overlay(
                    Group {
                        if binding.wrappedValue?.id == project.id {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor, lineWidth: 2)
                        }
                    }
                )
        } else {
            NavigationLink(destination: ProjectDetailView(project: project)) {
                ProjectGridCard(project: project)
            }
            .buttonStyle(.plain)
        }
    }
}
