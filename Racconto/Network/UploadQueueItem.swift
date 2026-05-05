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

    init(localPath: String, projectId: String, originalFilename: String, exif: EXIFData) {
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
    }
}
