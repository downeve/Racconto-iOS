import Foundation
import SwiftData
import UIKit

struct CFUploadURLResponse: Decodable {
    let uploadUrl: String
    let id: String

    enum CodingKeys: String, CodingKey {
        case uploadUrl = "uploadURL"
        case id
    }
}

@Observable
class UploadService {
    static let shared = UploadService()

    var pendingCount = 0
    var isUploading = false
    var completedCount = 0
    var lastErrorMessage: String? = nil

    private var isProcessing = false
    private let api = RaccontoAPI.shared
    private let container: ModelContainer = {
        try! ModelContainer(for: UploadQueueItem.self)
    }()
    private var context: ModelContext { container.mainContext }

    func enqueue(image: UIImage, exif: EXIFData, projectId: String, filename: String) {
        let resized = ImageResizer.resize(image)
        let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("upload_\(UUID().uuidString).jpg")
        let writeOK = (try? resized.write(to: localURL)) != nil
        print("[UploadService] enqueue: \(filename), 파일 저장 \(writeOK ? "성공" : "실패") → \(localURL.lastPathComponent)")

        let item = UploadQueueItem(
            localPath: localURL.path,
            projectId: projectId,
            originalFilename: filename,
            exif: exif
        )
        context.insert(item)
        try? context.save()
        pendingCount += 1
        print("[UploadService] pendingCount=\(pendingCount), processQueue 시작")

        Task { await processQueue() }
    }

    func processQueue() async {
        guard !isProcessing else {
            print("[UploadService] processQueue: 이미 처리 중, 건너뜀")
            return
        }
        isProcessing = true
        isUploading = true
        defer { isProcessing = false; isUploading = false }

        let descriptor = FetchDescriptor<UploadQueueItem>(
            predicate: #Predicate { $0.status == "pending" },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        do {
            let items = try context.fetch(descriptor)
            print("[UploadService] pending 항목 \(items.count)개 조회됨")
            guard !items.isEmpty else { pendingCount = 0; return }
            await processItems(items)
        } catch {
            print("[UploadService] fetch 실패: \(error)")
            pendingCount = 0
            return
        }

        let remaining = (try? context.fetch(
            FetchDescriptor<UploadQueueItem>(predicate: #Predicate { $0.status == "pending" })
        ))?.count ?? 0
        pendingCount = remaining
        print("[UploadService] 완료. 남은 pending=\(remaining)")
    }

    private func processItems(_ items: [UploadQueueItem]) async {

        for item in items {
            print("[UploadService] 업로드 시작: \(item.originalFilename) (retryCount=\(item.retryCount))")
            var uploaded = false
            while !uploaded && item.retryCount < 3 {
                item.status = "uploading"
                try? context.save()
                do {
                    try await uploadItem(item)
                    item.status = "done"
                    completedCount += 1
                    uploaded = true
                    print("[UploadService] 업로드 성공: \(item.originalFilename)")
                    try? FileManager.default.removeItem(atPath: item.localPath)
                } catch {
                    item.retryCount += 1
                    let desc: String
                    switch error {
                    case let apiErr as APIError: desc = apiErr.errorDescription ?? error.localizedDescription
                    case let urlErr as URLError: desc = "네트워크 오류 (\(urlErr.code.rawValue))"
                    default: desc = error.localizedDescription
                    }
                    lastErrorMessage = "[\(item.originalFilename)] \(desc)"
                    print("[UploadService] 실패 (시도 \(item.retryCount)/3): \(desc)")
                    if item.retryCount >= 3 {
                        item.status = "failed"
                    } else {
                        item.status = "pending"
                        try? await Task.sleep(for: .seconds(2))
                    }
                }
                try? context.save()
            }
        }
    }

    private func uploadItem(_ item: UploadQueueItem) async throws {
        let urlResp: CFUploadURLResponse = try await api.request("/photos/cf-upload-url")
        guard let imageData = FileManager.default.contents(atPath: item.localPath) else {
            throw URLError(.fileDoesNotExist)
        }
        let imageUrl = try await uploadToCloudflare(data: imageData, uploadUrl: urlResp.uploadUrl, imageId: urlResp.id)
        let req = PhotoMetadataRequest(
            projectId: item.projectId,
            imageUrl: imageUrl,
            originalFilename: item.originalFilename,
            camera: item.exifCamera,
            lens: item.exifLens,
            iso: item.exifIso,
            shutterSpeed: item.exifShutterSpeed,
            aperture: item.exifAperture,
            focalLength: item.exifFocalLength,
            gpsLat: item.exifGpsLat,
            gpsLng: item.exifGpsLng,
            takenAt: item.exifTakenAt
        )
        let _: Photo = try await api.request("/photos/", method: "POST", body: req)
    }

    func retryFailed() async {
        let descriptor = FetchDescriptor<UploadQueueItem>(
            predicate: #Predicate { $0.status == "failed" }
        )
        guard let failed = try? context.fetch(descriptor), !failed.isEmpty else { return }
        for item in failed {
            item.status = "pending"
            item.retryCount = 0
        }
        try? context.save()
        await processQueue()
    }

    var hasFailedItems: Bool {
        let descriptor = FetchDescriptor<UploadQueueItem>(
            predicate: #Predicate { $0.status == "failed" }
        )
        return ((try? context.fetch(descriptor))?.count ?? 0) > 0
    }

    private func uploadToCloudflare(data: Data, uploadUrl: String, imageId: String) async throws -> String {
        guard let url = URL(string: uploadUrl) else { throw URLError(.badURL) }
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // 업로드 URL에서 account hash 추출: https://upload.imagedelivery.net/{accountHash}/{token}
        let parts = uploadUrl.components(separatedBy: "/")
        let accountHash = parts.count > 3 ? parts[3] : ""
        return "https://imagedelivery.net/\(accountHash)/\(imageId)/public"
    }
}
