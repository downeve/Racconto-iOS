import UIKit

enum ImageResizer {
    /// Swift 6 default isolation 회피 — 순수 유틸이므로 nonisolated 명시해
    /// Task.detached 등 non-isolated 컨텍스트에서 호출 가능.
    nonisolated static func resize(_ image: UIImage, maxSize: Int = 3200) -> Data {
        // 픽셀 기준으로 계산 — image.size는 points라 scale을 곱해야 실제 픽셀 해상도.
        // PHPicker.loadObject는 보통 scale=1이지만, HEIC/문서 경로 등에서 scale≠1이면
        // points만 쓰면 의도보다 작게 리사이즈되는 문제 발생.
        let pixelW = image.size.width * image.scale
        let pixelH = image.size.height * image.scale
        let longest = max(pixelW, pixelH)
        let ratio = CGFloat(maxSize) / longest
        // 장변이 maxSize보다 클 때만 축소, 작으면 원본 픽셀 유지.
        let targetSize = ratio < 1
            ? CGSize(width: pixelW * ratio, height: pixelH * ratio)
            : CGSize(width: pixelW, height: pixelH)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1               // targetSize를 픽셀 그대로 사용 (point=pixel 1:1)
        format.opaque = true           // JPEG는 알파 불필요 → 32bpp RGBA 강제, 24bpp 경고 억제
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: targetSize, format: format)
            .jpegData(withCompressionQuality: 0.88) { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
    }
}
