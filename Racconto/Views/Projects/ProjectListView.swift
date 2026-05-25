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
            if viewModel.projects.isEmpty && !viewModel.isLoading {
                emptyState
            } else if isSidebar {
                sidebarList
            } else {
                phoneGrid
            }
        }
        .navigationTitle("프로젝트")
        .navigationBarTitleDisplayMode(isSidebar ? .inline : .large)
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

    // 빈 상태 — 신규 가입자 또는 모든 프로젝트 삭제 후
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "rectangle.stack")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("아직 프로젝트가 없습니다.")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("오른쪽 위 + 버튼으로\n새 프로젝트를 만들어 보세요.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button {
                showForm = true
            } label: {
                Label("새 프로젝트", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            Text("삭제")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.load() }
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
                            Text("삭제")
                        }
                    }
                }
            }
            .padding(12)
        }
        .refreshable { await viewModel.load() }
    }
}
