import UIKit

enum ImageResizer {
    /// 원본 데이터가 JPEG인지 매직바이트(FF D8 FF)로 판별.
    /// 웹의 `file.type === 'image/jpeg'` 분기와 동일 목적.
    nonisolated static func isJPEG(_ data: Data) -> Bool {
        data.count >= 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF
    }

    /// Swift 6 default isolation 회피 — 순수 유틸이므로 nonisolated 명시해
    /// Task.detached 등 non-isolated 컨텍스트에서 호출 가능.
    ///
    /// - Parameter sourceIsJPEG: 원본이 JPEG면 quality 0.92, 그 외(PNG/WEBP/HEIC 등)는 0.88.
    ///   웹 `resizeWorker.ts`의 `file.type === 'image/jpeg' ? 0.92 : 0.88` 정책과 동일.
    nonisolated static func resize(_ image: UIImage, sourceIsJPEG: Bool, maxSize: Int = 3200) -> Data {
        // 픽셀 기준으로 계산 — image.size는 points라 scale을 곱해야 실제 픽셀 해상도.
        // PHPicker.loadObject는 보통 scale=1이지만, HEIC/문서 경로 등에서 scale≠1이면
        // points만 쓰면 의도보다 작게 리사이즈되는 문제 발생.
        let pixelW = image.size.width * image.scale
        let pixelH = image.size.height * image.scale
        let longest = max(pixelW, pixelH)
        let ratio = CGFloat(maxSize) / longest
        // 장변이 maxSize보다 클 때만 축소, 작으면 원본 픽셀 유지 (업스케일 안 함).
        let targetSize = ratio < 1
            ? CGSize(width: pixelW * ratio, height: pixelH * ratio)
            : CGSize(width: pixelW, height: pixelH)

        // 웹과 동일: 원본 JPEG는 0.92, 그 외는 0.88.
        let quality: CGFloat = sourceIsJPEG ? 0.92 : 0.88

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1               // targetSize를 픽셀 그대로 사용 (point=pixel 1:1)
        format.opaque = true           // JPEG는 알파 불필요 → 32bpp RGBA 강제, 24bpp 경고 억제
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: targetSize, format: format)
            .jpegData(withCompressionQuality: quality) { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
    }
}
