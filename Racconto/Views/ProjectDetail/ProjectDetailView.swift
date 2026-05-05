import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @State private var selectedTab = 0
    @State private var photosVM = PhotosViewModel()
    @State private var storyVM = StoryViewModel()
    @State private var notesVM = NotesViewModel()

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
                PhotosTabView(project: project, viewModel: photosVM)
            case 1:
                StoryTabView(project: project, viewModel: storyVM)
            case 2:
                NotesTabView(project: project, viewModel: notesVM)
            default:
                EmptyView()
            }
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await photosVM.load(projectId: project.id)
        }
        .onChange(of: selectedTab) { _, tab in
            Task {
                switch tab {
                case 1: if storyVM.chapters.isEmpty { await storyVM.load(projectId: project.id) }
                case 2: if notesVM.notes.isEmpty { await notesVM.load(projectId: project.id) }
                default: break
                }
            }
        }
    }
}
