import SwiftUI

struct ProjectListView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    var viewModel: ProjectListViewModel
    var selectedProject: Binding<Project?>?

    @State private var showForm = false
    @State private var deleteAlert: Project? = nil

    private var isSidebar: Bool { selectedProject != nil }

var body: some View {
        Group {
            if isSidebar {
                sidebarList
            } else {
                phoneGrid
            }
        }
        .navigationTitle(isSidebar ? "" : "프로젝트")
        .navigationBarTitleDisplayMode(isSidebar ? .inline : .large)
        .toolbar(isSidebar ? .hidden : .automatic, for: .navigationBar)
        .toolbar {
            if !isSidebar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showForm = true } label: {
                        Image(systemName: "plus")
                    }
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

    // iPad 사이드바: 1열 리스트
    private var sidebarList: some View {
        List {
            ForEach(viewModel.projects) { project in
                ProjectCard(project: project)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedProject?.wrappedValue = project }
                    .background(
                        selectedProject?.wrappedValue?.id == project.id
                            ? Color.accentColor.opacity(0.08)
                            : Color.clear
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteAlert = project
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.load() }
        .safeAreaInset(edge: .bottom) {
            Button { showForm = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                    Text("새 프로젝트")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
    }

    // iPhone: 그리드 (2열 고정)
    private var phoneGrid: some View {
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

        return ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(viewModel.projects) { project in
                    NavigationLink(destination: ProjectDetailView(project: project)) {
                        ProjectGridCard(project: project)
                    }
                    .buttonStyle(.plain)
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
}
