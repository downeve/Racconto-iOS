import SwiftUI
import UniformTypeIdentifiers

/// Files 앱(문서 제공자)에서 이미지 파일을 선택. PHPicker(포토 라이브러리)로는 접근 불가한
/// 외부 저장 이미지(다운로드한 PNG/WEBP/HEIC 등) 업로드 경로.
///
/// PhotoPicker와 동일한 콜백 시그니처 `([(UIImage, Data, String)]) -> Void`를 사용해
/// 업로드 파이프라인(UploadService.enqueue)을 그대로 공유한다.
struct ImageDocumentPicker: UIViewControllerRepresentable {
    let onComplete: ([(UIImage, Data, String)]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // 웹 지원 포맷(jpeg/png/webp) + HEIC/HEIF. UTType.image는 이 모두를 포함하지만
        // 명시적으로 나열해 picker가 비이미지 파일을 흐리게 처리하도록 함.
        var types: [UTType] = [.jpeg, .png, .heic, .heif]
        if let webp = UTType("org.webmproject.webp") { types.append(webp) }
        types.append(.image) // 그 외 이미지 형식 폴백

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: ImageDocumentPicker

        init(_ parent: ImageDocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // asCopy: true이므로 보안 스코프 접근 없이 임시 복사본을 바로 읽을 수 있음.
            var items: [(UIImage, Data, String)] = []
            for url in urls {
                guard let data = try? Data(contentsOf: url),
                      let image = UIImage(data: data) else { continue }
                // 확장자 제거 후 .jpg 부착 — 실제 업로드는 JPEG 변환.
                let base = url.deletingPathExtension().lastPathComponent
                let filename = (base.isEmpty ? UUID().uuidString : base) + ".jpg"
                items.append((image, data, filename))
            }
            guard !items.isEmpty else { return }
            parent.onComplete(items)
        }
    }
}
