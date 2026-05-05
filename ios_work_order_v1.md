# 작업 지시서
## Racconto iOS/iPadOS — Swift Native 앱
**v1 — 웹과 기능 동등, App Store 출시 목표**

---

## 0. 전제 조건 및 핵심 원칙

- **최소 타겟:** iOS 18 / iPadOS 18
- **빌드 SDK:** iOS 26 SDK (Xcode 26) — App Store 제출 요건
- **UI 프레임워크:** SwiftUI 전용 (UIKit 직접 사용 금지, 필요 시 `UIViewRepresentable` 래퍼만 허용)
- **아키텍처:** MVVM + @Observable (Swift 5.9)
- **백엔드:** 기존 FastAPI 그대로 사용, 엔드포인트 변경 없음
- **이미지 서빙:** CF Images variant (`/public`, `/grid`, `/thumb`) 활용
- **기존 웹/Electron 코드 변경 없음**

---

## 1. 기술 스택

| 영역 | 채택 | 이유 |
|------|------|------|
| UI | SwiftUI | Claude Code 친화적, iPad 분기 자연스러움 |
| 상태관리 | @Observable (Observation framework) | SwiftUI 최적화, boilerplate 최소 |
| 네트워킹 | URLSession async/await | 백그라운드 업로드 지원 |
| 이미지 로딩/캐싱 | Kingfisher | CF Images variant URL, 디스크 캐시 |
| 사진 접근 | PhotosUI (PHPickerViewController) | iOS 14+ 권한 모델, 원본 접근 |
| 로컬 저장 | SwiftData | 업로드 큐, 오프라인 캐시 |
| 마크다운 렌더링 | swift-markdown-ui | 웹의 MarkdownRenderer와 동등 |
| 인증 | Keychain (KeychainAccess 라이브러리) | JWT 안전 저장 |
| 패키지 관리 | Swift Package Manager | |

### Swift Package 의존성

```swift
// Package.swift 또는 Xcode SPM
dependencies: [
    .package(url: "https://github.com/onevcat/Kingfisher", from: "7.0.0"),
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0"),
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.0.0"),
]
```

---

## 2. 데이터 구조 (백엔드 기반)

### 2-1. 핵심 모델

백엔드 `models.py`와 API 응답 기준으로 Swift 모델을 정의한다.

```swift
// MARK: - User / Auth
struct AuthResponse: Codable {
    let accessToken: String
    let tokenType: String
}

// MARK: - Project
struct Project: Codable, Identifiable {
    let id: String
    var title: String
    var description: String?
    var status: ProjectStatus
    var coverImageUrl: String?
    var location: String?
    var isPublic: String          // "true" | "false" — 백엔드가 String 반환
    var orderNum: Int
    var updatedAt: Date
    var createdAt: Date

    enum ProjectStatus: String, Codable {
        case inProgress = "in_progress"
        case completed
        case published
        case archived
    }
}

// MARK: - Photo
struct Photo: Codable, Identifiable {
    let id: String
    let projectId: String
    var imageUrl: String
    var caption: String?
    var order: Int
    var rating: Int?
    var colorLabel: String?       // "red" | "orange" | "yellow" | "green" | "blue"
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
    var localMissing: Bool
    var deletedAt: Date?
    var originalFilename: String?
    var folder: String?
}

// MARK: - Chapter (2계층 구조)
struct Chapter: Codable, Identifiable {
    let id: String
    let projectId: String
    var title: String
    var description: String?
    var orderNum: Int
    var parentId: String?         // nil이면 최상위 챕터
    var updatedAt: Date
    var createdAt: Date
}

// MARK: - ChapterItem
struct ChapterItem: Codable, Identifiable {
    let id: String
    let chapterId: String
    var orderNum: Int
    var itemType: ItemType        // "PHOTO" | "TEXT"
    var blockType: String         // "default" | "side-left" | "side-right"
    var blockLayout: BlockLayout  // "grid" | "wide" | "single"
    var blockId: String?
    var orderInBlock: Int
    // PHOTO 전용
    var photoId: String?
    var imageUrl: String?
    var caption: String?
    // TEXT 전용
    var textContent: String?

    enum ItemType: String, Codable {
        case photo = "PHOTO"
        case text = "TEXT"
    }

    enum BlockLayout: String, Codable {
        case grid, wide, single
    }
}

// MARK: - Note
struct Note: Codable, Identifiable {
    let id: String
    let projectId: String
    var content: String
    var noteType: String?         // "memo" | etc
    var isPinned: Bool
    var photoId: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
}

// MARK: - Portfolio (공개)
struct PortfolioProject: Codable, Identifiable {
    let id: String
    var title: String
    var description: String?
    var coverImageUrl: String?
    var location: String?
    var chapters: [PortfolioChapter]
    var photos: [PortfolioPhoto]
    var extraPhotos: [PortfolioPhoto]
}

struct PortfolioChapter: Codable, Identifiable {
    let id: String
    var title: String
    var description: String?
    var items: [PortfolioChapterItem]
    var subChapters: [PortfolioChapter]
}

struct PortfolioChapterItem: Codable {
    var itemType: String          // "PHOTO" | "TEXT"
    var id: String?
    var imageUrl: String?
    var caption: String?
    var blockLayout: String?      // "grid" | "wide" | "single"
    var textContent: String?
    var blockId: String?
    var blockType: String?
}
```

### 2-2. 챕터 계층 구조

```
Project
└── Chapter (최상위, parent_id = nil)
    ├── items: [ChapterItem]      // 이 챕터 직속 아이템
    └── SubChapter (parent_id = 최상위.id, 최대 1단계)
        └── items: [ChapterItem]
```

**규칙:**
- 챕터는 최대 2계층 (최상위 + 서브챕터)
- 서브챕터 아래 서브챕터는 API에서 400 에러 반환
- 챕터 목록 API(`GET /chapters/?project_id=`)는 flat list 반환 → 앱에서 `parent_id` 기준으로 트리 구성

### 2-3. 블록 구조

```
ChapterItem 그룹 = 블록
├── 같은 block_id를 공유하는 item들이 하나의 블록
├── block_type:
│   ├── "default"    → 일반 PHOTO 블록 (grid/wide/single 레이아웃)
│   ├── "side-left"  → Side-by-Side: 텍스트 왼쪽, 사진 오른쪽
│   └── "side-right" → Side-by-Side: 사진 왼쪽, 텍스트 오른쪽
├── block_layout (default 블록에만 적용):
│   ├── "grid"   → 3열 그리드 (iPad: 가로 최대)
│   ├── "wide"   → 2열
│   └── "single" → 1열 (전체 너비)
└── item_type:
    ├── "PHOTO" → photo_id, image_url, caption
    └── "TEXT"  → text_content (Markdown)
```

---

## 3. 네트워크 레이어

### 3-1. API 클라이언트

**파일:** `RaccontoAPI.swift`

```swift
@Observable
class RaccontoAPI {
    static let shared = RaccontoAPI()
    private let baseURL = "https://racconto.app/api"  // 프로덕션
    private var token: String? {
        get { try? Keychain().get("jwt_token") }
        set {
            if let v = newValue { try? Keychain().set(v, key: "jwt_token") }
            else { try? Keychain().remove("jwt_token") }
        }
    }

    var isAuthenticated: Bool { token != nil }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try JSONEncoder.racconto.encode(body) }
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            self.token = nil
            throw APIError.unauthorized
        }
        return try JSONDecoder.racconto.decode(T.self, from: data)
    }
}

// JSON 날짜 처리 — 백엔드가 ISO8601 반환
extension JSONDecoder {
    static let racconto: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
extension JSONEncoder {
    static let racconto: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

enum APIError: Error {
    case unauthorized
    case limitExceeded(String)
    case notFound
    case serverError(Int)
}
```

### 3-2. 업로드 서비스 (백그라운드 업로드)

**파일:** `UploadService.swift`

iOS 업로드는 Electron과 동일하게 CF Direct Upload 방식을 사용한다.

```swift
// 1. FastAPI에서 CF 업로드 URL 발급
// GET /photos/cf-upload-url → { uploadURL, id }

// 2. 이미지 리사이즈 (장변 3200px, JPEG quality 0.88)
// ImageIO 또는 UIGraphicsImageRenderer 사용

// 3. CF에 multipart/form-data POST (백그라운드 URLSession)
// URLSessionConfiguration.background(withIdentifier: "com.racconto.upload")

// 4. FastAPI POST /photos/ 로 메타데이터 저장
// { project_id, image_url, source: "ios", original_filename, ...EXIF }
```

**백그라운드 업로드 큐 (SwiftData):**

```swift
@Model
class UploadQueueItem {
    var id: String
    var localPath: String         // 앱 Documents에 임시 저장된 리사이즈 이미지 경로
    var projectId: String
    var status: String            // "pending" | "uploading" | "done" | "failed"
    var retryCount: Int
    var createdAt: Date
    var originalFilename: String
}
```

**EXIF 추출:** `ImageIO` 프레임워크 (`CGImageSourceCopyPropertiesAtIndex`)

**리사이즈:**
```swift
func resizeImage(_ image: UIImage, maxSize: Int = 3200) -> Data {
    let w = image.size.width, h = image.size.height
    let scale = CGFloat(maxSize) / max(w, h)
    let newSize = scale < 1
        ? CGSize(width: w * scale, height: h * scale)
        : image.size
    return UIGraphicsImageRenderer(size: newSize)
        .jpegData(withCompressionQuality: 0.88) { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
}
```

### 3-3. 주요 API 엔드포인트 목록

| 기능 | 메서드 | 경로 |
|------|--------|------|
| 로그인 | POST | `/auth/login` |
| 회원가입 | POST | `/auth/register` |
| 프로젝트 목록 | GET | `/projects/` |
| 프로젝트 생성 | POST | `/projects/` |
| 프로젝트 수정 | PUT | `/projects/{id}` |
| 프로젝트 삭제 | DELETE | `/projects/{id}` |
| 프로젝트 순서 변경 | PUT | `/projects/reorder` |
| 사진 목록 | GET | `/photos/?project_id=` |
| CF 업로드 URL 발급 | GET | `/photos/cf-upload-url` |
| 사진 메타데이터 저장 | POST | `/photos/` |
| 사진 수정 | PUT | `/photos/{id}` |
| 사진 소프트 삭제 | DELETE | `/photos/{id}` |
| 사진 영구 삭제 | DELETE | `/photos/bulk-permanent` |
| 사진 회전 | POST | `/photos/{id}/rotate` |
| 챕터 목록 | GET | `/chapters/?project_id=` |
| 챕터 생성 | POST | `/chapters/` |
| 챕터 수정 | PUT | `/chapters/{id}` |
| 챕터 삭제 | DELETE | `/chapters/{id}` |
| 챕터 순서 변경 | POST | `/chapters/reorder` |
| 챕터 아이템 목록 | GET | `/chapters/{id}/items` |
| 사진 아이템 추가 | POST | `/chapters/{id}/items/photo` |
| TEXT 블록 추가 | POST | `/chapters/{id}/items/text` |
| TEXT 블록 수정 | PUT | `/chapters/{id}/items/{item_id}/text` |
| 아이템 삭제 | DELETE | `/chapters/{id}/items/{item_id}` |
| 블록 간 사진 이동 | PUT | `/chapters/{id}/items/move-to-block` |
| 블록 내 순서 변경 | PUT | `/chapters/{id}/blocks/{block_id}/reorder` |
| 블록 레이아웃 변경 | PUT | `/chapters/{id}/blocks/{block_id}/layout` |
| 아이템 일괄 동기화 | PUT | `/chapters/{id}/items/bulk-sync` |
| 노트 목록 | GET | `/notes/?project_id=` |
| 노트 생성 | POST | `/notes/` |
| 노트 수정 | PUT | `/notes/{id}` |
| 노트 삭제 | DELETE | `/notes/{id}` |
| 공개 포트폴리오 | GET | `/portfolio/{username}` |
| 설정 조회 | GET | `/settings/` |
| 설정 변경 | PUT | `/settings/` |
| 휴지통 목록 | GET | `/photos/?include_deleted=true` |
| 사진 복구 | POST | `/photos/restore-by-filename` |

---

## 4. 앱 구조

### 4-1. iPhone vs iPad 분기

```swift
@main
struct RaccontoApp: App {
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some Scene {
        WindowGroup {
            if sizeClass == .regular {
                iPadRootView()   // iPad: NavigationSplitView
            } else {
                iPhoneRootView() // iPhone: NavigationStack + TabView
            }
        }
    }
}
```

**iPhone 레이아웃:**
```
TabView (하단)
├── 프로젝트 탭 (NavigationStack)
├── 포트폴리오 탭
└── 설정 탭
```

**iPad 레이아웃:**
```
NavigationSplitView
├── Sidebar: 프로젝트 목록 + 하단 네비
└── Detail: 프로젝트 상세 (Photos / Story / Notes 탭)
```

### 4-2. 파일 구조

```
Racconto/
├── App/
│   ├── RaccontoApp.swift
│   ├── iPhoneRootView.swift
│   └── iPadRootView.swift
├── Network/
│   ├── RaccontoAPI.swift
│   ├── UploadService.swift
│   └── APIError.swift
├── Models/
│   ├── Project.swift
│   ├── Photo.swift
│   ├── Chapter.swift
│   ├── ChapterItem.swift
│   ├── Note.swift
│   └── Portfolio.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── ProjectListViewModel.swift
│   ├── ProjectDetailViewModel.swift
│   ├── PhotosViewModel.swift
│   ├── StoryViewModel.swift
│   ├── NotesViewModel.swift
│   ├── PortfolioViewModel.swift
│   └── TrashViewModel.swift
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── RegisterView.swift
│   ├── Projects/
│   │   ├── ProjectListView.swift
│   │   ├── ProjectCard.swift
│   │   └── ProjectFormView.swift
│   ├── ProjectDetail/
│   │   ├── ProjectDetailView.swift      // 탭 컨테이너
│   │   ├── Photos/
│   │   │   ├── PhotosTabView.swift
│   │   │   ├── PhotoGridView.swift
│   │   │   ├── PhotoCard.swift
│   │   │   └── PhotoActionSheet.swift
│   │   ├── Story/
│   │   │   ├── StoryTabView.swift       // 편집/미리보기 토글
│   │   │   ├── StoryEditorView.swift    // 챕터 목록 + 블록 편집
│   │   │   ├── ChapterSection.swift     // 챕터 헤더 + 아이템
│   │   │   ├── BlockCard.swift          // 블록 카드 (사진 그리드 미리보기)
│   │   │   ├── PhotoBlockEditorView.swift  // PHOTO 블록 전체화면 편집
│   │   │   ├── TextBlockEditorView.swift   // TEXT 블록 전체화면 편집
│   │   │   ├── MoveBlockSheet.swift        // 블록 이동 선택
│   │   │   ├── SideBySideBlockView.swift   // Side-by-Side 블록
│   │   │   └── StoryPreviewView.swift      // 미리보기 모드
│   │   └── Notes/
│   │       ├── NotesTabView.swift
│   │       └── NoteCard.swift
│   ├── Portfolio/
│   │   ├── PublicPortfolioView.swift
│   │   ├── PortfolioChapterView.swift
│   │   └── PortfolioBlockView.swift
│   ├── Lightbox/
│   │   └── LightboxView.swift
│   ├── Trash/
│   │   └── TrashView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Common/
│       ├── MarkdownView.swift
│       ├── CachedImage.swift            // Kingfisher 래퍼
│       ├── UploadProgressView.swift
│       └── ConfirmDialog.swift
└── Utils/
    ├── CFImageURL.swift                 // variant URL 교체 유틸
    ├── ImageResizer.swift
    ├── EXIFExtractor.swift
    └── ChapterTreeBuilder.swift         // flat → tree 변환
```

---

## 5. 주요 화면 구현 명세

### 5-1. 인증

**LoginView / RegisterView**

- 이메일/패스워드 입력 폼
- 로그인: `POST /auth/login` → JWT → Keychain 저장
- 회원가입: `POST /auth/register` → 이메일 인증 안내
- Apple 로그인 불필요 (현재 백엔드 미지원, App Store 심사 시 소셜 로그인 없으면 필수 아님)
- 자동 로그인: 앱 시작 시 Keychain 토큰 확인

### 5-2. 프로젝트 목록

**ProjectListView**

- iPhone: 단일 컬럼 카드 리스트
- iPad: 사이드바 리스트 (좁음) — 선택 시 Detail 영역에 표시
- 카드: 커버 이미지(`thumb` variant) + 제목 + 상태 배지 + 위치
- 상태 배지 색상:
  - `in_progress` → 보라
  - `completed` → 초록
  - `published` → 파랑
  - `archived` → 회색
- 순서 변경: `EditButton` → 드래그 핸들 노출 → `PUT /projects/reorder`
- 새 프로젝트: `+` 버튼 → `ProjectFormView` sheet
- 삭제: 스와이프 → 확인 Alert → `DELETE /projects/{id}`
- `PROJECT_LIMIT_EXCEEDED` 에러 처리: Alert으로 안내

### 5-3. 프로젝트 상세

**ProjectDetailView**

탭 구성: **Photos / Story / Notes**

iPhone: `TabView` 또는 상단 `Picker` 세그먼트
iPad: 상단 `Picker` 세그먼트 (Detail 영역 내)

### 5-4. Photos 탭

**PhotosTabView / PhotoGridView**

**그리드:**
- iPhone: 기본 2열, 사용자 설정으로 1/2/3열 전환
- iPad: 기본 4열, 3/4/5열 전환
- `LazyVGrid` + `CachedImage(url, variant: .grid)`

**사진 업로드:**
- FAB `+` → `PHPickerViewController` (다중 선택)
- 선택한 사진 → `ImageResizer.resize(maxSize: 3200)` → EXIF 추출 → `UploadService` 큐에 추가
- 업로드 진행: `UploadProgressView` (하단 고정 바)
- `PHOTO_LIMIT_EXCEEDED` 에러 처리

**사진 액션 (롱프레스 → ActionSheet 또는 Context Menu):**
- 별점 1~5 설정 → `PUT /photos/{id}`
- 컬러 라벨 설정 (red/orange/yellow/green/blue)
- 커버로 지정 → `PUT /projects/{id}` (cover_image_url 변경)
- 챕터에 추가 → 챕터 선택 Sheet → `POST /chapters/{id}/items/photo`
- 라이트박스 열기
- 삭제 → 확인 → `DELETE /photos/{id}`

**다중 선택:**
- 툴바 "선택" 버튼 → 선택 모드
- 하단 바: 챕터 추가 / 삭제 / 취소

**필터:**
- 별점 필터, 컬러 라벨 필터 (클라이언트 사이드 필터링)

**사진 회전:**
- 라이트박스 내 회전 버튼 → `POST /photos/{id}/rotate`

### 5-5. Story 탭

**StoryTabView**

상단 세그먼트: **편집 | 미리보기**

---

#### 편집 모드: StoryEditorView

챕터 계층 구조를 유지하면서 블록 목록을 표시한다.

**ChapterTreeBuilder:**

```swift
// flat 챕터 목록을 2계층 트리로 변환
func buildTree(_ chapters: [Chapter]) -> [(parent: Chapter, subs: [Chapter])] {
    let tops = chapters.filter { $0.parentId == nil }.sorted { $0.orderNum < $1.orderNum }
    return tops.map { top in
        let subs = chapters.filter { $0.parentId == top.id }.sorted { $0.orderNum < $1.orderNum }
        return (top, subs)
    }
}
```

**화면 구성:**

```
ScrollView
└── ForEach(chapterTree) { (parent, subs) in
    // 최상위 챕터 헤더 (제목 + 순서 변경 버튼)
    ChapterHeaderView(chapter: parent)

    // 최상위 챕터 직속 블록
    ForEach(parentBlocks) { block in
        BlockCard(block: block)  // 탭 → 전체화면 편집
    }

    // 서브챕터
    ForEach(subs) { sub in
        SubChapterHeaderView(chapter: sub)
        ForEach(subBlocks) { block in
            BlockCard(block: block)
        }
    }
}
```

**BlockCard (블록 카드):**

```
┌──────────────────────────────────────┐
│ [≡] PHOTO 블록      [레이아웃] [⋮]   │
├──────────────────────────────────────┤
│ [img1] [img2] [+3]  (3×1 그리드)    │
│ 또는                                 │
│ "텍스트 미리보기 2줄..."   (TEXT)    │
└──────────────────────────────────────┘
```

- PHOTO 블록 썸네일: 앞 3장 `3×1` 가로 그리드, 나머지는 `+N` 오버레이
- 썸네일 순서: `order_in_block` 기준
- TEXT 블록: `text_content` 2줄 미리보기 (`lineLimit(2)`)
- Side-by-Side 블록: 사진 + 텍스트 가로 배치 미리보기
- 블록 순서 변경: 위/아래 버튼 (Phase 1) → `PUT /chapters/{id}/items/bulk-sync`
- 탭: PHOTO → `PhotoBlockEditorView`, TEXT → `TextBlockEditorView`
- `⋮` 메뉴: TEXT 블록만 삭제 가능

**챕터 관리:**
- 챕터 헤더 우측 `⋮` → 챕터 이름 수정 / 삭제 / 서브챕터 추가
- 새 챕터: 편집 화면 하단 FAB `+` → 챕터 생성 → `POST /chapters/`
- 챕터 순서 변경: 위/아래 버튼 → `POST /chapters/reorder`

**TEXT 블록 추가:**
- 상단 툴바 `+ 텍스트` 버튼 → 챕터 선택 Sheet → `POST /chapters/{id}/items/text`

---

#### PhotoBlockEditorView (PHOTO 블록 전체화면 편집)

```
NavigationStack {
    VStack {
        // 상단: 레이아웃 Picker (grid / wide / single)
        Picker("레이아웃", selection: $layout) { ... }
            .pickerStyle(.segmented)
            .onChange { PUT /chapters/{id}/blocks/{block_id}/layout }

        // 사진 목록 (순서 변경 가능)
        List {
            ForEach(photos) { photo in
                HStack {
                    CachedImage(photo.imageUrl, variant: .thumb)
                    Spacer()
                    // ⋮ 메뉴
                }
            }
            .onMove { PUT /chapters/{id}/blocks/{block_id}/reorder }
        }
        .environment(\.editMode, .constant(.active))
    }
    .navigationTitle("블록 편집")
    .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
    }
}
```

**개별 사진 `⋮` 메뉴:**
- 다른 블록으로 이동 → `MoveBlockSheet`
- 새 블록으로 이동 → `MoveBlockSheet`에서 `+` 선택
- 블록에서 제거 → `DELETE /chapters/{id}/items/{item_id}`

**빈 블록 자동 삭제:** 백엔드 `move-to-block` API가 자동 처리

---

#### MoveBlockSheet (블록 이동 선택)

웹의 `ConfirmModal(type: 'moveBlock')`을 Sheet로 재구현.

```swift
// 3열 그리드로 블록 썸네일 표시
LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
    ForEach(otherBlocks) { block in
        // block.firstImageUrl로 대표 썸네일 표시
        // aspect-[3/2]
    }
    // 마지막: 새 블록 슬롯 (+)
}
// API: PUT /chapters/{id}/items/move-to-block
// body: { item_id, target_block_id }  ("new" → 서버가 새 block_id 생성)
```

---

#### TextBlockEditorView (TEXT 블록 전체화면 편집)

```swift
NavigationStack {
    TextEditor(text: $draft)
        .font(.body)
    // 하단: 마크다운 미리보기 토글
    Toggle("미리보기", isOn: $showPreview)
    if showPreview {
        MarkdownView(content: draft)
    }
}
.toolbar {
    ToolbarItem(placement: .cancellationAction) { Button("취소") { ... } }
    ToolbarItem(placement: .confirmationAction) { Button("저장") {
        PUT /chapters/{id}/items/{item_id}/text
    }}
}
```

---

#### Side-by-Side 블록 (편집 모드)

**SideBySideBlockView:**

- 블록 카드에서 Side-by-Side 표시: 좌/우 배치 미리보기
- 탭 → `SideBySideEditorView` (전체화면)
  - 사진 목록 (세로 스택, 추가/제거)
  - 텍스트 영역 (탭 → `TextBlockEditorView`)
  - 방향 전환: 텍스트 왼쪽(side-left) / 텍스트 오른쪽(side-right)
  - "분리" 버튼 → `POST /chapters/{id}/items/{item_id}/cancel-side-by-side` (또는 관련 API)

**Side-by-Side 생성:**
웹에서는 텍스트 블록 아래/위에 사진 블록이 있을 때 "결합" 버튼으로 생성.
iOS에서는 Phase 1에서 기존 Side-by-Side 블록 편집만 지원. 신규 생성은 Phase 2.

---

#### 미리보기 모드: StoryPreviewView

웹의 `PortfolioChapterItems`와 동일한 렌더링.

**블록별 렌더링:**

```swift
// 일반 PHOTO 블록
switch block.layout {
case .grid:
    // LazyVGrid(columns: 3열 - iPhone, 4열 - iPad)
case .wide:
    // LazyVGrid(columns: 2열)
case .single:
    // VStack, 각 사진 전체 너비
}

// Side-by-Side 블록
HStack(spacing: 16) {
    if blockType == "side-right" {
        photoColumn
        textColumn
    } else {
        textColumn
        photoColumn
    }
}
// iPhone에서는 VStack으로 전환 (sizeClass == .compact)

// TEXT 블록
MarkdownView(content: item.textContent ?? "")
    .font(.custom("Georgia", size: 16))
    .lineSpacing(8)
```

**챕터 헤더:**
- 최상위 챕터: 제목 + 설명 (큰 폰트)
- 서브챕터: 제목 + 설명 (중간 폰트)
- 챕터 간 구분선 또는 여백

**이미지 탭 → Lightbox**

---

### 5-6. Notes 탭

**NotesTabView**

- 노트 카드 리스트 (`isPinned` 상단 고정)
- 노트 타입: "memo" 등 — 아이콘으로 구분
- 새 노트: FAB `+` → 인라인 텍스트 에디터 → `POST /notes/`
- 수정: 탭 → 전체화면 에디터 → `PUT /notes/{id}`
- 삭제: 스와이프 → `DELETE /notes/{id}`
- 핀 고정: 스와이프 액션 → `PUT /notes/{id}` (`is_pinned` 토글)

### 5-7. Lightbox

**LightboxView**

- 전체화면 모달
- `TabView(selection:)` + `.tabViewStyle(.page)` 로 사진 스와이프
- 이미지: `CachedImage(url, variant: .public)` (3200px)
- 상단: 닫기 + `n / total` 인덱스
- 하단 고정 바:
  - 별점 (1~5, `PUT /photos/{id}`)
  - 컬러 라벨 (5색)
  - 챕터 추가 버튼 → 챕터 선택 Sheet
  - 회전 버튼 (좌/우) → `POST /photos/{id}/rotate`
  - EXIF 정보 토글
- EXIF 패널: 카메라, 렌즈, ISO, 셔터, 조리개, 초점거리, 날짜, GPS

### 5-8. 공개 포트폴리오

**PublicPortfolioView**

- `GET /portfolio/{username}` — 인증 불필요
- username 입력 → 포트폴리오 표시
- 테마 (light/dark): API 응답의 `theme` 값 적용
- 프로젝트 카드 목록 → 탭 → `PortfolioChapterView`

**PortfolioChapterView:**
- 챕터 계층 구조 표시 (최상위 + 서브챕터)
- `PortfolioBlockView`: 블록 타입별 렌더링

**이미지 비율 기반 레이아웃 (renderRow 대응):**
```swift
// 웹의 renderRow를 대응
// GeometryReader로 컨테이너 너비 측정
// 이미지 로드 후 aspect ratio 계산
// flex 비율 기반 너비 분배
GeometryReader { geo in
    let containerWidth = geo.size.width
    // 각 사진의 비율 합으로 행 높이 계산
    // iPhone: rowHeight = containerWidth * 0.45
    // iPad: rowHeight = containerWidth * 0.35
}
```

### 5-9. 휴지통

**TrashView**
- `GET /photos/?include_deleted=true` → `deleted_at != nil` 필터
- 사진 그리드 (2열)
- 복구: 스와이프 → `POST /photos/restore-by-filename`
- 영구 삭제: 스와이프 → 확인 → `DELETE /photos/bulk-permanent`

### 5-10. 설정

**SettingsView**
- 포트폴리오 테마 (light/dark) → `PUT /settings/`
- 계정 정보 표시
- 로그아웃 → Keychain 토큰 삭제

---

## 6. CF Images Variant URL 유틸

**파일:** `CFImageURL.swift`

```swift
enum CFVariant: String {
    case `public` = "public"   // 3200px — 라이트박스
    case grid = "grid"         // 800px  — 그리드 뷰
    case thumb = "thumb"       // 400px  — 카드 커버, 미리보기
}

func cfUrl(_ imageUrl: String?, variant: CFVariant = .public) -> URL? {
    guard let imageUrl, !imageUrl.isEmpty else { return nil }
    guard imageUrl.contains("imagedelivery.net") else { return URL(string: imageUrl) }
    // URL 끝의 variant 교체
    let base = imageUrl.hasSuffix("/")
        ? String(imageUrl.dropLast())
        : imageUrl
    let noVariant = base.components(separatedBy: "/").dropLast().joined(separator: "/")
    return URL(string: "\(noVariant)/\(variant.rawValue)")
}
```

**CachedImage 래퍼:**
```swift
struct CachedImage: View {
    let url: String?
    var variant: CFVariant = .public
    var contentMode: ContentMode = .fill

    var body: some View {
        KFImage(cfUrl(url, variant: variant))
            .placeholder { Color.gray.opacity(0.1) }
            .resizable()
            .aspectRatio(contentMode: contentMode)
    }
}
```

---

## 7. iPhone / iPad UI 차이 요약

| 요소 | iPhone | iPad |
|------|--------|------|
| 네비게이션 | TabView + NavigationStack | NavigationSplitView |
| 사진 그리드 기본 열 | 2열 | 4열 |
| 사진 그리드 범위 | 1~3열 | 3~5열 |
| Story 블록 목록 | 전체 화면 | Detail 영역 내 |
| Side-by-Side | 세로 스택 | 가로 배치 |
| 포트폴리오 행 높이 | containerWidth * 0.45 | containerWidth * 0.35 |
| 미리보기 그리드 | 2열 | 4열 |
| 라이트박스 하단 바 | 아이콘만 | 아이콘 + 레이블 |

---

## 8. 작업 순서 (Phase)

### Phase 0 — 프로젝트 설정 및 기반

| 순서 | 작업 |
|------|------|
| P0-1 | Xcode 프로젝트 생성, SPM 의존성 추가 (Kingfisher, swift-markdown-ui, KeychainAccess) |
| P0-2 | `RaccontoAPI.swift` — 네트워크 레이어 + JSONDecoder 설정 |
| P0-3 | 모든 Model 파일 생성 |
| P0-4 | `CFImageURL.swift`, `ImageResizer.swift`, `EXIFExtractor.swift` |
| P0-5 | `AuthViewModel` + `LoginView` + `RegisterView` |
| P0-6 | `iPhoneRootView` + `iPadRootView` 분기 구조 |

### Phase 1 — 핵심 기능

| 순서 | 작업 |
|------|------|
| P1-1 | `ProjectListViewModel` + `ProjectListView` + `ProjectCard` |
| P1-2 | `ProjectDetailView` (탭 컨테이너) |
| P1-3 | `PhotosViewModel` + `PhotosTabView` + `PhotoGridView` + `PhotoCard` |
| P1-4 | `UploadService` (백그라운드 업로드 + SwiftData 큐) |
| P1-5 | `PHPickerViewController` 연동 + 업로드 흐름 완성 |
| P1-6 | `LightboxView` |
| P1-7 | `ChapterTreeBuilder` + `StoryViewModel` |
| P1-8 | `StoryEditorView` + `BlockCard` (블록 목록) |
| P1-9 | `PhotoBlockEditorView` + `MoveBlockSheet` |
| P1-10 | `TextBlockEditorView` |
| P1-11 | `SideBySideBlockView` (편집 전용 — 기존 블록 편집) |
| P1-12 | `StoryPreviewView` + `PortfolioBlockView` (렌더링) |
| P1-13 | `NotesTabView` + `NoteCard` |

### Phase 2 — 완성도

| 순서 | 작업 |
|------|------|
| P2-1 | `PublicPortfolioView` + `PortfolioChapterView` |
| P2-2 | `TrashView` |
| P2-3 | `SettingsView` |
| P2-4 | Side-by-Side 신규 생성 (웹과 동등) |
| P2-5 | 블록 순서 변경 → 드래그 핸들 (`.onMove` → bulk-sync) |
| P2-6 | 챕터 순서 변경 드래그 |
| P2-7 | 오프라인 대응 (실패 큐 재시도) |
| P2-8 | iPad 멀티태스킹 / Stage Manager 대응 |

### Phase 3 — App Store

| 순서 | 작업 |
|------|------|
| P3-1 | 앱 아이콘, 스플래시 스크린 |
| P3-2 | Privacy Manifest (`PrivacyInfo.xcprivacy`) — Photos 접근 사유 명시 |
| P3-3 | TestFlight 배포 |
| P3-4 | App Store Connect 메타데이터 (스크린샷, 설명) |
| P3-5 | App Store 심사 제출 |

---

## 9. App Store 심사 주의 사항

- **Photos 접근 권한:** `NSPhotoLibraryUsageDescription` — `Info.plist`에 반드시 명시
- **백그라운드 모드:** `Background fetch`, `Remote notifications` 필요 시 Capabilities 추가
- **네트워크 보안:** `NSAppTransportSecurity` — HTTPS만 사용 중이므로 별도 설정 불필요
- **소셜 로그인:** 타사 로그인(Google 등) 없으므로 Apple 로그인 강제 없음. 이메일만이면 통과
- **개인정보 처리방침 URL:** App Store Connect에 필수 입력

---

## 10. 검증 체크리스트

### 공통
- [ ] iPhone / iPad에서 레이아웃이 올바르게 분기되는가 (`horizontalSizeClass`)
- [ ] JWT가 Keychain에 안전하게 저장/삭제되는가
- [ ] 앱 재시작 후 자동 로그인이 동작하는가
- [ ] `PHOTO_LIMIT_EXCEEDED` / `PROJECT_LIMIT_EXCEEDED` 에러 Alert이 표시되는가

### 업로드
- [ ] PHPicker에서 선택한 사진이 장변 3200px로 리사이즈되는가
- [ ] 앱 백그라운드 전환 후에도 업로드가 완료되는가
- [ ] 업로드 실패 항목이 큐에 남아 재시도되는가
- [ ] EXIF(카메라, 날짜, GPS)가 메타데이터에 저장되는가
- [ ] `source: "ios"`로 저장되는가

### Story 편집
- [ ] 챕터 계층(최상위 + 서브챕터)이 올바르게 표시되는가
- [ ] BlockCard 썸네일이 `order_in_block` 기준으로 정렬되는가
- [ ] PHOTO 블록 전체화면에서 레이아웃 변경이 API에 반영되는가
- [ ] 블록 내 사진 순서 변경이 `reorder` API에 반영되는가
- [ ] 블록 간 사진 이동 후 빈 블록이 자동 삭제되는가
- [ ] TEXT 블록 저장/취소가 올바르게 동작하는가
- [ ] Side-by-Side 블록이 iPhone에서 세로 스택으로 전환되는가
- [ ] 미리보기 모드에서 모든 블록 타입이 렌더링되는가

### 이미지
- [ ] 그리드 뷰에서 `grid`(800px) variant가 사용되는가
- [ ] 라이트박스에서 `public`(3200px) variant가 사용되는가
- [ ] 커버/카드에서 `thumb`(400px) variant가 사용되는가
- [ ] CF URL이 아닌 URL에서 `cfUrl()`이 원본을 그대로 반환하는가
