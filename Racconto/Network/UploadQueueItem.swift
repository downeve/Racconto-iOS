import SwiftData
import Foundation

@Model
class UploadQueueItem {
    var id: String
    var localPath: String
    var projectId: String
    var status: String          // "pending" | "uploading" | "done" | "failed"
    var retryCount: Int
    var createdAt: Date
    var originalFilename: String
    var exifCamera: String?
    var exifLens: String?
    var exifIso: String?
    var exifShutterSpeed: String?
    var exifAperture: String?
    var exifFocalLength: String?
    var exifTakenAt: String?
    var exifGpsLat: String?
    var exifGpsLng: String?
    /// P-7: 이미지 원본 차원 — 업로드 직후 PhotoMetadataRequest로 전송.
    var width: Int?
    var height: Int?

    init(localPath: String, projectId: String, originalFilename: String, exif: EXIFData, width: Int?, height: Int?) {
        self.id = UUID().uuidString
        self.localPath = localPath
        self.projectId = projectId
        self.status = "pending"
        self.retryCount = 0
        self.createdAt = Date()
        self.originalFilename = originalFilename
        self.exifCamera = exif.camera
        self.exifLens = exif.lens
        self.exifIso = exif.iso
        self.exifShutterSpeed = exif.shutterSpeed
        self.exifAperture = exif.aperture
        self.exifFocalLength = exif.focalLength
        self.exifTakenAt = exif.takenAt
        self.exifGpsLat = exif.gpsLat
        self.exifGpsLng = exif.gpsLng
        self.width = width
        self.height = height
    }
}
