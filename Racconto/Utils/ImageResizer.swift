import UIKit

enum ImageResizer {
    static func resize(_ image: UIImage, maxSize: Int = 3200) -> Data {
        let w = image.size.width
        let h = image.size.height
        let scale = CGFloat(maxSize) / max(w, h)
        let newSize = scale < 1
            ? CGSize(width: w * scale, height: h * scale)
            : image.size
        return UIGraphicsImageRenderer(size: newSize)
            .jpegData(withCompressionQuality: 0.88) { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
    }
}
