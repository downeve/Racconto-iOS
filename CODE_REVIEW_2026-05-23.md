# Racconto iOS 코드 검토 보고서

날짜: 2026-05-23
대상: /Users/downeve/Racconto-iOS/Racconto
검토 파일 수: 57개 Swift 파일 (총 ~8,243줄)

## 요약
- 🔴 Critical: 6건
- 🟡 Warning: 14건
- 🔵 Info: 9건

---

## 1. 보안

### 🟡 [S-1] 운영 빌드에서도 출력되는 무조건적 print 로그 (민감정보 포함)

**파일**: `Racconto/Network/UploadService.swift:36, 47, 54, 67, 71, 80, 86, 96, 107`
**문제**: `UploadService` 전반에서 `#if DEBUG` 없이 `print(...)`를 호출한다. 파일명, 로컬 경로, retry 카운트, 에러 메시지 등이 그대로 시스템 로그(OSLog/Console.app)에 노출된다.
**근거**:
```swift
print("[UploadService] enqueue: \(filename), 파일 저장 \(writeOK ? "성공" : "실패") → \(localURL.lastPathComponent)")
...
print("[UploadService] 실패 (시도 \(item.retryCount)/3): \(desc)")
```
`RaccontoAPI.swift:71-78`는 `#if DEBUG`로 가드되어 있는 반면 `UploadService`는 가드가 없음.
**영향**: App Store 빌드에서도 사용자 파일명/에러가 Console에 기록되어 동일 기기를 사용하는 다른 앱 또는 시스템 로그 수집기에서 관찰 가능. 사진가의 작품 파일명이 노출될 수 있음.
**권장**: 모든 `print(...)`를 `#if DEBUG ... #endif`로 감싸거나 `OSLog`(.debug 레벨) 사용으로 통일.

---

### 🟡 [S-2] OAuth 콜백 URL의 토큰을 쿼리스트링으로 수신 (로그 누출 위험)

**파일**: `Racconto/ViewModels/AuthViewModel.swift:127-135`
**문제**: Google/Naver/LINE OAuth 흐름에서 JWT 토큰을 콜백 URL의 쿼리 파라미터(`?token=...`)로 받음. `ASWebAuthenticationSession`은 안전하지만, 백엔드 redirect 체인 중간 서버 로그/리퍼러/캐시에 토큰이 남을 가능성 존재.
**근거**:
```swift
guard let callbackURL,
      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
      let token = components.queryItems?.first(where: { $0.name == "token" })?.value else { ... }
self.api.setToken(token)
```
**영향**: 어차피 https + 커스텀 스킴이라 단말기 외부 누출은 제한적이지만, OAuth 모범사례는 fragment(`#token=`) 또는 PKCE + code exchange로 바꾸는 것.
**권장**: 백엔드와 협의해 fragment 전송 또는 1회용 code 교환 방식으로 변경. 최소한 토큰을 받은 즉시 URL을 폐기.

---

### 🟡 [S-3] 토큰 401 자동 폐기 시 사용자에게 알림 없음 — 세션 만료가 조용히 진행

**파일**: `Racconto/Network/RaccontoAPI.swift:51-53, 126-128`
**문제**: 401 응답을 받으면 `self.token = nil`로 Keychain에서 토큰을 제거하지만, `AuthViewModel.isAuthenticated`는 동기화되지 않음. 다음 API 호출까지 UI는 로그인 상태로 보이고, 다른 모든 호출이 무인증으로 나가서 401을 연속으로 받음.
**근거**:
```swift
case 401:
    self.token = nil
    throw APIError.unauthorized
```
`AuthViewModel.isAuthenticated`는 init에서 1회만 `api.isAuthenticated`를 읽음.
**영향**: 토큰 만료 시 UX 혼란, 불필요한 401 호출 다수 발생.
**권장**: 401 시 `NotificationCenter` post 또는 `AuthViewModel`에 `onTokenInvalidated` 클로저를 주입해 `isAuthenticated = false`를 트리거.

---

### 🔵 [S-4] 디버그 디코딩 오류 로그에 응답 본문 최대 2000자 출력

**파일**: `Racconto/Network/RaccontoAPI.swift:71-78`
**문제**: `#if DEBUG`로 가드되어 있어 운영에는 영향 없으나, 디버그 빌드에서 응답 원문에 사용자 데이터(이메일, 노트 본문, 위치)가 포함된 채 콘솔 출력됨.
**근거**:
```swift
print("응답 원문: \(raw.prefix(2000))")
```
**영향**: 개발 머신에 사용자 사진/노트 텍스트 평문 로그 잔존. 일반적으로 허용 가능하나 PII 처리 정책에 따라 다름.
**권장**: 응답 본문 출력은 길이만 출력하거나 별도 환경변수로 명시적 활성화.

---

### 🔵 [S-5] 마크다운 렌더링 — XSS 표면은 작지만 외부 링크 처리 미확인

**파일**: `Racconto/Views/Portfolio/PortfolioBlockView.swift:72`, `Views/ProjectDetail/Notes/NoteCard.swift:40`, 등 8곳
**문제**: `MarkdownUI`를 사용해 사용자/타인 텍스트를 렌더. iOS 네이티브 환경에서는 JS 실행이 불가하므로 전통적 XSS는 없으나, 마크다운 링크 `[text](javascript:...)` 또는 `[text](file://...)` 처리 정책을 코드상에서 확인할 수 없음.
**근거**: `Markdown(preprocessMarkdown(text))` — 별도 링크 필터링 없음.
**영향**: 악성 포트폴리오를 열람한 사용자에게 의도치 않은 스킴 핸들러 호출 가능성.
**권장**: `MarkdownUI` 설정에서 안전한 스킴(`https`, `http`, `mailto`)만 허용하도록 `openURL` action을 명시적으로 구성.

---

### 🔵 [S-6] CF Direct Upload URL — 재사용 가능성 (백엔드와 일관성)

**파일**: `Racconto/Network/UploadService.swift:121-125`, `ViewModels/StoryViewModel.swift:151-154`
**문제**: 매 사진마다 새 `/photos/cf-upload-url`을 요청하므로 재사용은 아님. 단, 업로드 실패 시 동일 URL을 재시도 루프(`while !uploaded && item.retryCount < 3`)에서 사용하지 않고 각 시도마다 `uploadItem()`이 새 URL을 요청 — 안전. 다만 Cloudflare 정책상 발급된 URL은 30분 단발성이므로 재시도가 30분 이상 지연되면 실패함.
**근거**: `processItems`의 retry 루프는 URL을 캐시하지 않고 매 시도마다 `uploadItem()` → 새 URL 발급으로 안전.
**권장**: 변경 불필요. 단지 검증 결과 안전함을 기록.

---

## 2. 성능

### 🔴 [P-1] `ChapterPickerSheet` — 챕터마다 별도 API 호출 (N+1)

**파일**: `Racconto/Views/Common/ChapterPickerSheet.swift:77-89`
**문제**: 사진의 챕터 소속 여부를 확인하려고 모든 챕터에 대해 `/chapters/{id}/items`를 병렬로 호출. 챕터 N개 → 요청 N개.
**근거**:
```swift
await withTaskGroup(of: (String, Bool).self) { group in
    for chapter in chapters {
        group.addTask {
            let items: [ChapterItem]? = try? await api.request("/chapters/\(chapter.id)/items")
            let has = items?.contains { $0.photoId == pid } ?? false
            return (chapter.id, has)
        }
    }
    ...
}
```
**영향**: 챕터가 20개면 시트 열 때마다 21번의 네트워크 호출 + 모든 챕터 아이템 다운로드. 라이트박스에서 사진 사이를 넘기면서 매번 호출됨.
**권장**: 백엔드에 `/photos/{id}/chapters` 같은 단일 엔드포인트 추가 또는 시트 진입 시점에 이미 메모리에 로드된 `StoryViewModel.itemsByChapter`를 주입해 재사용.

---

### 🟡 [P-2] `LightboxView` — 모든 사진을 한 번에 TabView로 렌더, prefetch 없음

**파일**: `Racconto/Views/Lightbox/LightboxView.swift:58-67`
**문제**: `TabView(selection:)` + `ForEach(Array(photos.enumerated()))` 패턴. SwiftUI TabView는 페이지 스타일에서도 모든 페이지 뷰를 메모리에 유지하려 함. 사진 수백 장 프로젝트에서 메모리 압박.
**근거**:
```swift
TabView(selection: $currentIndex) {
    ForEach(Array(photos.enumerated()), id: \.element.id) { idx, photo in
        ZoomablePhotoView(url: photo.imageUrl) { ... }
    }
}
```
Kingfisher가 캐시는 하지만, `KFImage`는 onAppear에서 로드하므로 전체 즉시 로드는 아닐 수 있음. 그러나 인접 페이지 prefetch를 명시적으로 하지 않아 스와이프 시 흰 placeholder가 잠깐 보임.
**영향**: 300+장 라이트박스 진입 시 메모리 스파이크, 스와이프 시 로딩 깜빡임.
**권장**: 인접 ±2 페이지만 렌더(LazyPager 패턴) 또는 Kingfisher `ImagePrefetcher`로 인접 URL 선프리패치.

---

### 🟡 [P-3] `Block.firstImageUrl` / 정렬/필터 매번 재계산

**파일**: `Racconto/ViewModels/PhotosViewModel.swift:41-65`, `Models/Block.swift:11-14`
**문제**: `filteredPhotos`는 computed property. `@Observable` 컨텍스트에서 뷰가 갱신될 때마다 매번 전체 사진 배열을 필터 + 정렬. 1000장 한도까지 모두 메모리에 있으므로 매 키스트로크/스크롤마다 O(N log N).
**근거**:
```swift
var filteredPhotos: [Photo] {
    var result = photos.filter { ... }
    switch sortBy { ... result.sort { ... } }
    return result
}
```
**영향**: 사진 많은 프로젝트에서 필터 변경 시 한 박자 늦은 반응.
**권장**: `didSet`/`onChange`에서 한 번만 계산해 저장. 또는 `lazy filter + sorted`로 변경.

---

### 🟡 [P-4] `StoryViewModel.load()` — 모든 챕터의 아이템을 한꺼번에 병렬 로드

**파일**: `Racconto/ViewModels/StoryViewModel.swift:33-39`
**문제**: 프로젝트 진입 시 모든 챕터의 아이템을 동시에 fetch. 챕터가 많고 각 챕터에 사진이 많은 프로젝트에서 초기 대기 + 메모리 사용 큼.
**근거**:
```swift
await withTaskGroup(of: Void.self) { group in
    for chapter in chapters {
        group.addTask { await self.loadItems(for: chapter.id) }
    }
}
```
**영향**: 챕터 50개짜리 프로젝트에서 50개의 동시 HTTP 요청 → 서버 부하 + 클라이언트 메모리. URLSession 기본 동시성 한도(host당 4)에 의해 직렬화되지만 그래도 모든 응답 메모리 누적.
**권장**: `expandedChapterId` 챕터만 우선 로드, 나머지는 펼칠 때 lazy 로드(이미 `loadItems(for:)` 존재).

---

### 🟡 [P-5] `EXIFExtractor.extract` / `ImageResizer.resize` 메인 스레드 차단 가능

**파일**: `Racconto/Views/ProjectDetail/Photos/PhotosTabView.swift:111-121`, `Utils/EXIFExtractor.swift`, `Utils/ImageResizer.swift`
**문제**: 사진 선택 후 picker 콜백에서 동기적으로 `EXIFExtractor.extract(from: data)` 호출. UIImage 디코딩 + EXIF 파싱이 메인 스레드에서 일어남. `ImageResizer.resize`도 `enqueue` 동기 경로(`UploadService.swift:32`)에서 메인 스레드 차단.
**근거**:
```swift
PhotoPicker { items in
    for (image, data, filename) in items {
        let exif = EXIFExtractor.extract(from: data)        // <- main thread
        UploadService.shared.enqueue(image: image, ...)      // <- 내부에서 resize도 동기
    }
}
```
`UploadService.enqueue`:
```swift
let resized = ImageResizer.resize(image)
```
**영향**: 사용자가 한 번에 50장 선택하면 메인 스레드가 수 초간 정지, UI freeze.
**권장**: `enqueue`를 async로 바꾸고 내부에서 `Task.detached` / background queue에서 resize와 EXIF 파싱 수행.

---

### 🟡 [P-6] `viewModel.sortBy` 변경 시 UserDefaults에 저장 안 됨

**파일**: `Racconto/ViewModels/PhotosViewModel.swift:27-32`, `Views/ProjectDetail/Photos/PhotosTabView.swift:85-91`
**문제**: init에서 UserDefaults를 읽어 `sortBy`를 초기화하지만, 사용자가 메뉴에서 정렬을 바꿔도 UserDefaults에 다시 쓰지 않음. 다음 진입 시 옛 값으로 복귀.
**근거**:
```swift
init() {
    let savedSortBy = UserDefaults.standard.string(forKey: "photo_sort_by")
    sortBy = PhotoSortBy(rawValue: savedSortBy ?? "") ?? .default
    ...
}
// 메뉴에서:
Button { viewModel.sortBy = s } label: { ... }   // UserDefaults 미반영
```
설정 화면(`SettingsView.savePhotoSort()`)에서만 UserDefaults에 기록됨.
**영향**: 사용자가 즉석에서 바꾼 정렬이 세션 종료 시 사라지는 일관성 문제. 성능 문제는 아니지만 UX 결함.
**권장**: `didSet`에서 `UserDefaults.standard.set(...)` 또는 SettingsView처럼 일관된 경로로 통합.

---

### 🔵 [P-7] `KFImage.onSuccess`에서 ratio 상태 업데이트 → 재레이아웃 폭증

**파일**: `Racconto/Views/Portfolio/PortfolioBlockView.swift:206-221`, `258-272`
**문제**: `SingleFitPhoto`와 `PortfolioJustifiedPhotoGrid`가 이미지 로드 성공 시 `ratio` 상태를 갱신. 그리드는 동일 row 안의 모든 ratio가 모이기 전까지 잘못된 높이로 한 번 렌더 후 재계산.
**영향**: 큰 포트폴리오에서 첫 진입 시 레이아웃 점프(점프 스크롤) 발생.
**권장**: 백엔드가 이미지 가로/세로 메타데이터를 같이 내려주거나, intrinsic content size 캐시를 한 번만 계산.

---

## 3. UX 및 버그 가능성

### 🔴 [U-1] `PhotosViewModel.softDelete` — 에러 복구 시 `load(projectId: "")` 호출

**파일**: `Racconto/ViewModels/PhotosViewModel.swift:102-107`
**문제**: 소프트 삭제 실패 시 빈 문자열을 projectId로 넘겨 재로드. `/photos/?project_id=` 호출 결과로 사진 목록이 비거나 잘못된 사진들이 표시될 수 있음.
**근거**:
```swift
func softDelete(photoId: String) async {
    photos.removeAll { $0.id == photoId }
    do {
        try await api.requestVoid("/photos/\(photoId)", method: "DELETE")
    } catch { await load(projectId: "") }   // <- 잘못된 ID
}
```
**영향**: 삭제 실패 시 사진 목록이 깨지거나 사라짐. 사용자는 사진이 진짜 삭제된 것으로 오해.
**권장**: `softDelete(photoId:projectId:)`로 시그니처 확장하거나 `self`에 projectId를 저장해 사용.

---

### 🔴 [U-2] force unwrap 4곳 — CLAUDE.md 규칙 위반

**파일**:
- `Racconto/Network/UploadService.swift:27` — `try! ModelContainer(for: UploadQueueItem.self)`
- `Racconto/Network/UploadService.swift:171, 173` — `.data(using: .utf8)!`
- `Racconto/ViewModels/StoryViewModel.swift:185, 187` — `.data(using: .utf8)!`
- `Racconto/ViewModels/TrashViewModel.swift:43` — `groups[photo.projectId]!.photos.append(photo)`
- `Racconto/Views/Auth/LandingView.swift:9` — `URL(string: "https://racconto.app/register")!`

**문제**: CLAUDE.md "Swift: force unwrap 금지" 규칙 위반.
**영향**:
- `try! ModelContainer`: SwiftData 스키마 마이그레이션 실패 시 앱 즉시 크래시 (현재는 단일 모델이라 실패 가능성 낮지만 향후 모델 변경 시 위험).
- `data(using: .utf8)!`: ASCII 문자열만 사용하므로 실질 안전하나 규칙 위반.
- `groups[id]!`: 직전 라인에서 초기화하므로 안전하지만 코드 변경 시 버그 유발.
- `URL(string:)!`: 하드코딩 URL이라 안전.
**권장**: `try!` → `try? ... ?? fatalError(...)` 또는 명시적 do/catch, 나머지는 옵셔널 바인딩 또는 `guard`로 변환.

---

### 🔴 [U-3] `RaccontoAPI` baseURL이 하드코딩된 운영 URL — DEBUG 빌드도 운영 백엔드 사용

**파일**: `Racconto/Network/RaccontoAPI.swift:7`
**문제**: `private let baseURL = "https://racconto.app/api"` — 빌드 컨피그/스킴별 분기 없음. CLAUDE.md에 명시된 "dev는 localhost:8000" 정책은 Electron에만 적용되고 iOS는 항상 운영을 가리킴.
**근거**: `AuthViewModel.swift:108`에서도 동일하게 하드코딩 (`baseURL = "https://racconto.app/api"`).
**영향**: 개발/테스트 시 운영 DB에 부작용. 또한 운영 도메인 변경 시 컴파일 재빌드 필요.
**권장**: `Info.plist`의 `RACCONTO_API_URL` 또는 `#if DEBUG` 분기.

---

### 🔴 [U-4] `@Observable` 클래스 7개 중 6개가 `@MainActor` 누락 — UI 상태 변경의 스레드 안전성 미보장

**파일**:
- `Racconto/ViewModels/AuthViewModel.swift:4` (메서드 단위 `@MainActor`만 있음)
- `Racconto/ViewModels/NotesViewModel.swift:3`
- `Racconto/ViewModels/PhotosViewModel.swift:16`
- `Racconto/ViewModels/PortfolioViewModel.swift:3`
- `Racconto/ViewModels/ProjectDetailViewModel.swift:3`
- `Racconto/ViewModels/ProjectListViewModel.swift:4`
- `Racconto/ViewModels/TrashViewModel.swift:3`
**문제**: 오직 `StoryViewModel`만 `@MainActor`. 다른 VM은 async/await 호출 이후 `notes.insert`, `photos[idx] = updated` 등 상태 변경을 수행하는데, await 후 어느 actor로 돌아오는지 보장 안 됨.
**근거**:
```swift
@Observable
class NotesViewModel {  // <- @MainActor 없음
    ...
    func create(...) async {
        ...
        let note: Note = try await api.request(...)
        notes.insert(note, at: 0)   // <- await 후 메인 스레드 보장 X
    }
}
```
**영향**: SwiftUI `@Observable` 상태를 비메인 스레드에서 변경 시 런타임 경고 + UI 갱신 race condition.
**권장**: 모든 VM에 `@MainActor` 일괄 적용. 또는 `await MainActor.run { ... }`로 변경 부분만 감쌈.

---

### 🟡 [U-5] `TrashView` — 동일 셀에 `.contextMenu` 두 번 적용

**파일**: `Racconto/Views/Trash/TrashView.swift:129-156`
**문제**: 사진 셀에 `.contextMenu`가 두 번 연속 적용되어 있음. SwiftUI는 마지막 것만 사용 → 위쪽 컨텍스트 메뉴는 죽은 코드.
**근거**: 라인 129 시작 `.contextMenu { ... }`와 라인 145 시작 `.contextMenu { ... }` — 내용 동일하지만 두 번 선언.
**영향**: 코드 중복, 추후 수정 시 한쪽만 바꿔서 버그.
**권장**: 한 번만 적용.

---

### 🟡 [U-6] `ZWSP` / `ZWNJ` 사용 — 빈 텍스트 우회와 마크다운 전처리

**파일**: `Racconto/ViewModels/StoryViewModel.swift:137, 202`, `Views/ProjectDetail/Story/StoryTokens.swift:45-74`
**문제**:
- `StoryViewModel`이 서버의 "빈 문자열 거부" 검증을 우회하려고 `\u{200B}`(ZWSP)를 보냄.
- `preprocessMarkdown`은 right-flanking 조건 우회를 위해 `\u{200C}`(ZWNJ) 삽입.
두 유니코드 문자가 데이터에 영구 저장되며 검색/복사/외부 export에서 보이지 않는 noise로 남음.
**근거**:
```swift
let safeContent = content.isEmpty ? "\u{200B}" : content
```
**영향**: 향후 데이터를 다른 플랫폼(웹, RSS, JSON export)에 노출했을 때 보이지 않는 문자가 검색 실패/diff 노이즈의 원인.
**권장**: 서버 측 빈 텍스트 정책을 명시적으로 허용하도록 백엔드 수정 — 우회는 임시방편.

---

### 🟡 [U-7] `UIScreen.main.bounds` 사용 — iOS 16+ Deprecated

**파일**: `Racconto/Views/ProjectDetail/Story/TextBlockEditorView.swift:89`
**문제**: iOS 18 최소 타겟임에도 `UIScreen.main.bounds.width` 사용. 멀티윈도우/Split View에서 잘못된 폭 반환.
**근거**: `let width = proposal.width ?? UIScreen.main.bounds.width`
**영향**: iPad Split View에서 텍스트 에디터 폭이 전체 화면 폭으로 계산되어 잘림.
**권장**: `proposal.width ?? 0` 사용, 또는 GeometryReader로 부모 폭 측정.

---

### 🟡 [U-8] `iPhoneRootView` 구조체 이름이 lowercase로 시작 — 스타일 규칙 위반

**파일**: `Racconto/App/iPhoneRootView.swift:3`, `Racconto/App/iPadRootView.swift:3`
**문제**: Swift 타입은 UpperCamelCase가 표준. `iPhoneRootView`, `iPadRootView`는 소문자 시작.
**영향**: 기능적 문제 없음. 스타일/관습 위반.
**권장**: 향후 새 타입 추가 시 일관성 유지.

---

### 🟡 [U-9] `ProjectListViewModel.move`가 reorder 응답으로 전체 배열 교체 — 진행 중 다른 변경 분실 가능

**파일**: `Racconto/ViewModels/ProjectListViewModel.swift:45-55`
**문제**: 드래그 후 백엔드 응답으로 `projects = updated`. 그 사이 새 프로젝트가 다른 경로로 추가됐다면 사라짐.
**근거**:
```swift
let updated: [Project] = try await api.request("/projects/reorder", method: "PUT", body: req)
projects = updated
```
**영향**: 드래그 정렬과 동시 작업 시 데이터 누락. 단일 사용자 단일 기기에서는 드뭄.
**권장**: ID 기준 머지 또는 서버 시간 비교.

---

### 🟡 [U-10] `UploadService.processQueue`의 `isProcessing` 가드는 다중 호출 시 후속 enqueue 손실 위험

**파일**: `Racconto/Network/UploadService.swift:52-81`
**문제**: `processQueue` 진입 시 `isProcessing` true면 즉시 return. 진행 중에 `enqueue`가 호출되어 새 pending이 들어와도 새 `processQueue` 호출은 즉시 종료. 진행 중인 루프는 시작 시점의 fetch 결과만 처리.
**근거**: `processItems` 루프 안에서 새로 들어온 pending을 다시 fetch하지 않음. 루프 종료 후 다시 fetch하긴 하지만, 동시성 충돌 시 second processQueue가 noop.
**영향**: 빠른 연속 enqueue 시 일부 사진이 pending 상태로 머무르고 다음 enqueue 또는 앱 재실행까지 업로드 시작 안 됨.
**권장**: 루프 종료 후 `pending`이 남아있으면 한 번 더 루프 수행 (이미 `remaining` 카운트는 보여주나 처리는 안 함).

---

### 🟡 [U-11] `PhotoPicker.didFinishPicking` — `picker.dismiss` 호출 후 비동기로 콜백, 사용자가 빈 상태에서 대기

**파일**: `Racconto/Views/ProjectDetail/Photos/PhotoPicker.swift:25-42`
**문제**: dismiss 후 image/data 로드를 Task로 비동기 처리. 50장 선택 시 dismiss는 즉시지만 콜백은 수 초 후 → 그 사이 사용자가 다른 동작을 하면 race.
**권장**: 진행 인디케이터 또는 picker를 유지한 채 로드.

---

### 🟡 [U-12] `LightboxView.portfolioTopBar` — 우상단 `ellipsis` 버튼이 빈 액션

**파일**: `Racconto/Views/Lightbox/LightboxView.swift:113-118`
**근거**: `Button { } label: { Image(systemName: "ellipsis") ... }` — 액션 비어있음.
**영향**: 사용자가 누르면 아무 일도 안 일어남. 또는 `PortfolioProjectDetailView.swift:137`의 bookmark 버튼도 동일.
**권장**: 미구현이면 숨기거나 disabled.

---

### 🟡 [U-13] `NoteCard` Markdown clipping — 긴 단락 미리보기에서 잘림이 자연스럽지 않음

**파일**: `Racconto/Views/ProjectDetail/Notes/NoteCard.swift:40-43`
**문제**: `Markdown(...)`에 `.frame(maxHeight: 64)` + `.clipped()`. 마크다운 헤딩이 1줄 차지하면 본문이 거의 안 보임. 라인 단위 잘림이 아니라 픽셀 단위.
**권장**: `lineLimit(3)` 추가 또는 plain text 미리보기 전용으로 별도 처리.

---

### 🔵 [U-14] `AuthViewModel.fetchMe`의 에러 무시

**파일**: `Racconto/ViewModels/AuthViewModel.swift:37`
**근거**: `} catch {}`
**영향**: 토큰 만료가 fetchMe에서 발생하면 401 → API가 토큰을 삭제하지만 VM은 모름. (S-3과 연관)
**권장**: 401일 때 `isAuthenticated = false` 처리.

---

### 🔵 [U-15] 다수 VM이 에러를 조용히 삼킴 (`catch {}`)

**파일** (전체 18곳 이상):
- `NotesViewModel.swift:22, 32, 40, 47`
- `PhotosViewModel.swift:90, 99, 114, 122, 129, 136`
- `StoryViewModel.swift:42, 49, 70, 78, 91, 127, 174, ...`
- `TrashViewModel.swift:55, 62, 69, 79`
**문제**: 네트워크 실패가 사용자에게 보이지 않고 UI 상태만 어긋남(예: 노트 togglePin 실패 시 핀 상태 불일치).
**권장**: 최소한 `errorMessage`에 기록하거나 토스트 표시.

---

### 🔵 [U-16] `EmptyResponse: Decodable {}` — 빈 body 디코딩 실패 가능

**파일**: `Racconto/ViewModels/AuthViewModel.swift:164`
**문제**: `/auth/register` 응답을 `EmptyResponse`로 디코딩. 백엔드가 JSON object를 반환하면 성공하지만 빈 응답(`""`)을 반환하면 디코딩 실패 → `errorMessage` 설정.
**권장**: `api.requestVoid`를 사용해 응답 본문 무시.

---

### 🔵 [U-17] `ProjectDetailView` — 사진 탭만 .task에서 로드, 챕터/노트는 onChange로 lazy

**파일**: `Racconto/Views/ProjectDetail/ProjectDetailView.swift:63-73`
**문제**: 첫 진입 시 사진 탭 데이터만 로드. 사용자가 곧장 스토리 탭으로 가도 정상 동작은 하지만, 첫 탭 전환 후 로딩이 보임. 일관되지 않음.
**권장**: 모든 탭의 초기 로드를 한 번에 시작 또는 명시적으로 lazy 정책 문서화.

---

### 🔵 [U-18] `iPadRootView`에서 `NavigationStack`을 비프로젝트 탭에 사용 — Sidebar/Detail 구조와 불일치

**파일**: `Racconto/App/iPadRootView.swift:19-29`
**문제**: 프로젝트 탭만 NavigationSplitView, 나머지(포트폴리오/휴지통/설정)는 NavigationStack. iPad UX 가이드라인상 모두 SplitView를 권장. 기능 결함은 아님.
**권장**: 의도된 결정이라면 무시. 그렇지 않다면 통일.

---

## 좋은 점

- **JWT는 Keychain 저장** (`RaccontoAPI:8-19`) — UserDefaults가 아닌 올바른 보안 저장소 사용.
- **JSONDecoder/Encoder.racconto** — snake_case 변환과 fractional seconds 가진 ISO8601 fallback 처리 견고함 (`RaccontoAPI:144-178`).
- **이미지 variant 분리** (`CFImageURL.swift`) — thumb/grid/public 3단계로 트래픽 최적화.
- **Apple Sign In은 native** (identity token POST) — 웹 OAuth 대비 안전.
- **Markdown right-flanking 우회** (`StoryTokens.preprocessMarkdown`) — CommonMark 엣지케이스 정확히 인지하고 ZWNJ로 해결. 주석 품질도 좋음.
- **`PortfolioProjectDetailView.collectPhotos`의 url 기반 fallback id** — UUID 대신 안정 fallback 사용해 SwiftUI ForEach 재렌더 방지 (주석에서 명시).
- **`IME 조합 보호`** (`TextBlockEditorView.updateUIView`) — 한글 조합 중 attributedText 재설정 회피. 한국어 UX에 필수적.
- **소셜 사용자에게 비밀번호 변경/탈퇴 비밀번호 입력 분기** (`SettingsView.swift`) — `isSocialUser` 분기 깔끔.
- **Side-by-side / chapter / block 모델링** — 데이터/뷰 분리가 명확하고 `groupItemsIntoBlocks`/`buildTree`가 순수 함수로 분리되어 테스트 가능.
- **Kingfisher + variant URL** — 적절한 이미지 캐싱.

---

## 우선순위 권장 작업

1. **U-4 (`@MainActor` 누락)** — 모든 ViewModel에 일괄 적용. SwiftUI 6에서 런타임 경고/이상 동작 가능성 큼.
2. **U-3 (DEBUG/Release baseURL 분기)** — 개발 환경 보호.
3. **P-1 (ChapterPickerSheet N+1)** — 백엔드 엔드포인트 추가 또는 메모리 캐시 재사용.
4. **U-1 (`load(projectId: "")`)** — 단순 버그, 한 줄 수정.
5. **S-1 (UploadService print)** — `#if DEBUG` 감싸기.
6. **P-5 (메인 스레드 이미지 처리)** — 다량 업로드 사용자 경험에 직결.
