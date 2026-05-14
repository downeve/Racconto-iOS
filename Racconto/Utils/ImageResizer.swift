import UIKit

enum ImageResizer {
    static func resize(_ image: UIImage, maxSize: Int = 3200) -> Data {
        let w = image.size.width
        let h = image.size.height
        let scale = CGFloat(maxSize) / max(w, h)
        let newSize = scale < 1
            ? CGSize(width: w * scale, height: h * scale)
            : image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true   // JPEG는 알파 불필요 → 32bpp RGBA 강제, 24bpp 경고 억제
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: newSize, format: format)
            .jpegData(withCompressionQuality: 0.88) { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
    }
}
