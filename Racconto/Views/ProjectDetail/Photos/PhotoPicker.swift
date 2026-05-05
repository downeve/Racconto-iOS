import SwiftUI
import PhotosUI

struct PhotoPicker: UIViewControllerRepresentable {
    let onComplete: ([(UIImage, Data, String)]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }

            Task {
                var items: [(UIImage, Data, String)] = []
                for result in results {
                    guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
                    async let imageLoad = loadImage(from: result.itemProvider)
                    async let dataLoad  = loadData(from: result.itemProvider)
                    if let image = await imageLoad, let data = await dataLoad {
                        let filename = result.itemProvider.suggestedName ?? UUID().uuidString
                        items.append((image, data, "\(filename).jpg"))
                    }
                }
                await MainActor.run { parent.onComplete(items) }
            }
        }

        private func loadImage(from provider: NSItemProvider) async -> UIImage? {
            await withCheckedContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    continuation.resume(returning: object as? UIImage)
                }
            }
        }

        private func loadData(from provider: NSItemProvider) async -> Data? {
            await withCheckedContinuation { continuation in
                provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, _ in
                    continuation.resume(returning: data)
                }
            }
        }
    }
}
