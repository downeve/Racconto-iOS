import Foundation

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
