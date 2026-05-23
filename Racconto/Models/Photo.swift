import Foundation
import CoreGraphics

struct Photo: Codable, Identifiable {
    let id: String
    let projectId: String
    var imageUrl: String
    var caption: String?
    var order: Int
    var rating: Int?
    var colorLabel: String?       // "red" | "yellow" | "green" | "blue" | "purple"
    var takenAt: Date?
    var camera: String?
    var lens: String?
    var iso: String?
    var shutterSpeed: String?
    var aperture: String?
    var focalLength: String?
    var gpsLat: String?
    var gpsLng: String?
    var source: String?           // "web" | "electron" | "ios"
    var localMissing: Bool?
    var deletedAt: Date?
    var originalFilename: String?
    var folder: String?
    var rotation: Int?
    var originalImageUrl: String?
    var isRotating: Bool?
    /// P-7: 이미지 원본 차원 (서버 응답에서 받음, 없을 수도 있음 — 백필 전 사진)
    var width: Int?
    var height: Int?

    /// 비율(가로/세로) — width/height가 모두 있으면 정확값, 없으면 nil.
    /// PortfolioBlockView가 nil인 경우 KFImage onSuccess fallback 경로로 폴백.
    var aspectRatio: CGFloat? {
        guard let w = width, let h = height, h > 0 else { return nil }
        return CGFloat(w) / CGFloat(h)
    }
}

struct PhotoMetadataRequest: Encodable {
    var projectId: String
    var imageUrl: String
    var source: String = "ios"
    var originalFilename: String?
    var caption: String?
    var camera: String?
    var lens: String?
    var iso: String?
    var shutterSpeed: String?
    var aperture: String?
    var focalLength: String?
    var gpsLat: String?
    var gpsLng: String?
    var takenAt: String?          // ISO8601 string
    /// P-7: 업로드 직후 클라이언트가 UIImage.size에서 측정해 전달.
    var width: Int?
    var height: Int?
}

struct PhotoUpdateRequest: Encodable {
    var rating: Int?
    var colorLabel: String?
    var caption: String?
    var coverImageUrl: String?
}

struct BulkPermanentDeleteRequest: Encodable {
    var photoIds: [String]
}
