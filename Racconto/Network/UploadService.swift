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
        do {
            return try ModelContainer(for: UploadQueueItem.self)
        } catch {
            // SwiftData 스토어 초기화 실패는 복구 불가 — 앱이 큐를 유지할 수 없으므로 명시적 중단.
            fatalError("UploadQueueItem ModelContainer 생성 실패: \(error)")
        }
    }()
    private var context: ModelContext { container.mainContext }

    /// EXIF 파싱 + 리사이즈 + 디스크 쓰기는 백그라운드에서 수행.
    /// SwiftData(mainContext) 작업과 관찰 가능한 상태 변경만 메인 컨텍스트에서.
    func enqueue(image: UIImage, data: Data, projectId: String, filename: String) async {
        let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("upload_\(UUID().uuidString).jpg")

        // P-7: 원본 차원 측정 (UIImage.size는 메인스레드 외에서도 안전).
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)

        // 무거운 작업을 background로
        let (exif, writeOK): (EXIFData, Bool) = await Task.detached(priority: .userInitiated) {
            let exif = EXIFExtractor.extract(from: data)
            let resized = ImageResizer.resize(image)
            let ok = (try? resized.write(to: localURL)) != nil
            return (exif, ok)
        }.value

        #if DEBUG
        print("[UploadService] enqueue: \(filename), 파일 저장 \(writeOK ? "성공" : "실패") → \(localURL.lastPathComponent)")
        #else
        _ = writeOK
        #endif

        let item = UploadQueueItem(
            localPath: localURL.path,
            projectId: projectId,
            originalFilename: filename,
            exif: exif,
            width: width,
            height: height
        )
        context.insert(item)
        try? context.save()
        pendingCount += 1
        #if DEBUG
        print("[UploadService] pendingCount=\(pendingCount), processQueue 시작")
        #endif

        Task { await processQueue() }
    }

    func processQueue() async {
        guard !isProcessing else {
            #if DEBUG
            print("[UploadService] processQueue: 이미 처리 중, 건너뜀")
            #endif
            return
        }
        isProcessing = true
        isUploading = true
        defer { isProcessing = false; isUploading = false }

        let descriptor = FetchDescriptor<UploadQueueItem>(
            predicate: #Predicate { $0.status == "pending" },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        // 처리 중 새로 enqueue된 항목 누락 방지 — 비어있을 때까지 루프.
        // 무한루프 안전장치: 최대 10회 반복 (현실적으로 한 세션 내 도달 불가).
        var loopGuard = 0
        while loopGuard < 10 {
            loopGuard += 1
            do {
                let items = try context.fetch(descriptor)
                #if DEBUG
                print("[UploadService] pending 항목 \(items.count)개 조회됨 (반복 \(loopGuard))")
                #endif
                if items.isEmpty { break }
                await processItems(items)
            } catch {
                #if DEBUG
                print("[UploadService] fetch 실패: \(error)")
                #endif
                break
            }
        }

        let remaining = (try? context.fetch(
            FetchDescriptor<UploadQueueItem>(predicate: #Predicate { $0.status == "pending" })
        ))?.count ?? 0
        pendingCount = remaining
        #if DEBUG
        print("[UploadService] 완료. 남은 pending=\(remaining)")
        #endif
    }

    private func processItems(_ items: [UploadQueueItem]) async {

        for item in items {
            #if DEBUG
            print("[UploadService] 업로드 시작: \(item.originalFilename) (retryCount=\(item.retryCount))")
            #endif
            var uploaded = false
            while !uploaded && item.retryCount < 3 {
                item.status = "uploading"
                try? context.save()
                do {
                    try await uploadItem(item)
                    item.status = "done"
                    completedCount += 1
                    uploaded = true
                    #if DEBUG
                    print("[UploadService] 업로드 성공: \(item.originalFilename)")
                    #endif
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
                    #if DEBUG
                    print("[UploadService] 실패 (시도 \(item.retryCount)/3): \(desc)")
                    #endif
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
            takenAt: item.exifTakenAt,
            width: item.width,
            height: item.height
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

        // multipart boundary는 ASCII만 사용 — utf8 인코딩 실패 가능성 없음. 규칙상 옵셔널 바인딩.
        let head = "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n"
        let tail = "\r\n--\(boundary)--\r\n"
        guard let headData = head.data(using: .utf8),
              let tailData = tail.data(using: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        var body = Data()
        body.append(headData)
        body.append(data)
        body.append(tailData)
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
