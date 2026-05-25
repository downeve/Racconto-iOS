import Foundation
import ImageIO
import CoreLocation

struct EXIFData {
    var camera: String?
    var lens: String?
    var iso: String?
    var shutterSpeed: String?
    var aperture: String?
    var focalLength: String?
    var takenAt: String?          // ISO8601
    var gpsLat: String?
    var gpsLng: String?
}

enum EXIFExtractor {
    /// Swift 6 default isolation 회피 — 순수 유틸이므로 nonisolated 명시해
    /// Task.detached 등 non-isolated 컨텍스트에서 호출 가능.
    nonisolated static func extract(from data: Data) -> EXIFData {
        var result = EXIFData()
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else { return result }

        let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let gps  = props[kCGImagePropertyGPSDictionary as String] as? [String: Any]

        result.camera = tiff?[kCGImagePropertyTIFFModel as String] as? String
        result.lens   = exif?[kCGImagePropertyExifLensModel as String] as? String

        if let iso = (exif?[kCGImagePropertyExifISOSpeedRatings as String] as? [Int])?.first {
            result.iso = "ISO \(iso)"
        }
        if let exp = exif?[kCGImagePropertyExifExposureTime as String] as? Double {
            if exp < 1 {
                let denom = Int(round(1.0 / exp))
                result.shutterSpeed = "1/\(denom)"
            } else {
                result.shutterSpeed = "\(Int(exp))s"
            }
        }
        if let f = exif?[kCGImagePropertyExifFNumber as String] as? Double {
            result.aperture = String(format: "f/%.1f", f)
        }
        if let fl = exif?[kCGImagePropertyExifFocalLength as String] as? Double {
            result.focalLength = "\(Int(fl))mm"
        }
        if let dateStr = exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            result.takenAt = isoDate(from: dateStr)
        }

        if let lat = gps?[kCGImagePropertyGPSLatitude as String] as? Double,
           let latRef = gps?[kCGImagePropertyGPSLatitudeRef as String] as? String,
           let lng = gps?[kCGImagePropertyGPSLongitude as String] as? Double,
           let lngRef = gps?[kCGImagePropertyGPSLongitudeRef as String] as? String {
            let finalLat = latRef == "S" ? -lat : lat
            let finalLng = lngRef == "W" ? -lng : lng
            result.gpsLat = String(finalLat)
            result.gpsLng = String(finalLng)
        }

        return result
    }

    private static func isoDate(from exifDate: String) -> String? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        guard let date = fmt.date(from: exifDate) else { return nil }
        let iso = ISO8601DateFormatter()
        return iso.string(from: date)
    }
}
