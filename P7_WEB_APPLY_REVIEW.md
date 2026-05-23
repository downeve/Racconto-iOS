# P-7 웹 적용 검토 (Portfolio 레이아웃 점프 제거)

날짜: 2026-05-23
대상: iOS와 동일한 백엔드/마이그레이션 활용해 웹도 무중단 혜택 받기.

## 현 상태

### 백엔드 (이미 작업 완료)
- `photos` 테이블에 `width`, `height` INT 컬럼 추가 (마이그레이션 v11)
- `PhotoResponse` Pydantic 스키마에 `width`/`height` 노출
- `portfolio.py`의 `_build_chapter_photos`와 extra/all photos dict에 `width`/`height` 포함
- 신규 업로드 (iOS): `PhotoMetadataRequest`에 차원 전송됨
- 신규 업로드 (웹/Electron): **아직 width/height를 보내지 않음** → 작업 필요
- 백필 스크립트: `backend/scripts/backfill_photo_dimensions.py`

### 웹 프론트엔드 (작업 필요)

영향 파일:
- `frontend/src/components/PortfolioChapterItems.tsx` — JustifiedGrid + side-by-side 모두 `naturalWidth/naturalHeight` 사용
- `frontend/src/pages/PublicPortfolio.tsx` — 라이트박스, 카드 (대부분 fix size라 영향 적음)

## 웹 작업 범위

### 1. 업로드 시 차원 전송

`frontend/src/components/PhotoUpload.tsx` 또는 사진 추가 흐름에서, Cloudflare 업로드 직후 metadata POST 시 width/height 동봉.

**가장 간단한 방식 — File API로 측정:**

```typescript
async function getImageDimensions(file: File): Promise<{width: number, height: number}> {
  return new Promise((resolve, reject) => {
    const img = new Image()
    const url = URL.createObjectURL(file)
    img.onload = () => {
      URL.revokeObjectURL(url)
      resolve({ width: img.naturalWidth, height: img.naturalHeight })
    }
    img.onerror = (e) => {
      URL.revokeObjectURL(url)
      reject(e)
    }
    img.src = url
  })
}

// 업로드 핸들러 안에서:
const dims = await getImageDimensions(file)
await axios.post(`${API}/photos/`, {
  project_id: projectId,
  image_url: imageUrl,
  original_filename: file.name,
  width: dims.width,
  height: dims.height,
  // ... 기존 EXIF/메타
})
```

**Electron의 경우:**

Electron `main.js`의 업로드 큐(`queue.js`)에서 sharp 또는 Node native image API로 차원 측정 후 metadata에 포함.
이미 sharp 설치되어 있다면 한두 줄 추가:
```js
const metadata = await sharp(filepath).metadata()
photoMetadata.width = metadata.width
photoMetadata.height = metadata.height
```

### 2. 렌더 시 점프 제거

`PortfolioChapterItems.tsx` — iOS의 `SingleFitPhoto.initialRatio` 패턴과 동일:

```tsx
// 변경 전: onLoad로 ratio 계산
const [imageRatios, setImageRatios] = useState<Record<string, number>>({})
const handleImageLoad = (url, e) => {
  const img = e.currentTarget
  setImageRatios(prev => ({ ...prev, [url]: img.naturalWidth / img.naturalHeight }))
}

// 변경 후: 서버 메타데이터 우선 사용
const [imageRatios, setImageRatios] = useState<Record<string, number>>(() => {
  // 초기 상태에 서버 width/height 채움
  const initial: Record<string, number> = {}
  photos.forEach(p => {
    if (p.width && p.height && p.height > 0 && p.image_url) {
      initial[p.image_url] = p.width / p.height
    }
  })
  return initial
})

const handleImageLoad = (url, e, hasServerDims) => {
  if (hasServerDims) return  // 서버값 우선
  const img = e.currentTarget
  setImageRatios(prev => ({ ...prev, [url]: img.naturalWidth / img.naturalHeight }))
}
```

`<img>` 태그에는 `width`/`height` 속성을 직접 명시해 브라우저가 reflow 전에 공간을 확보하게 함:

```tsx
<img
  src={cfUrl(photo.image_url, 'public')}
  width={photo.width || undefined}      // 명시적 차원 → 브라우저 native 비율 예약
  height={photo.height || undefined}
  loading="lazy"
  onLoad={(e) => handleImageLoad(photo.image_url, e, !!photo.width)}
  // ... 기존 스타일
/>
```

### 3. 백엔드 PhotoCreate에 width/height 추가

이미 `routers/photos.py:281-283`에 추가됨. 별도 작업 없음.

### 4. TypeScript 인터페이스

`PortfolioChapterItems.tsx`의 Photo 인터페이스:
```typescript
interface Photo {
  id: string
  image_url?: string
  caption?: string
  width?: number       // 추가
  height?: number      // 추가
}
```

## 혜택

- **Portfolio 그리드 진입 시 첫 페인트부터 정확한 카드 높이** — 스크롤 점프 사라짐
- `<img width height>` 명시로 브라우저 CLS(Cumulative Layout Shift) 점수 개선 → Lighthouse SEO에도 긍정적
- 라이트박스도 미리 종횡비 알 수 있어 placeholder 박스 정확
- 이미 백엔드 + 마이그레이션이 끝나 있으므로 **프론트엔드 변경만으로 즉시 혜택**

## 작업 순서 권장

1. 백필 스크립트 운영 서버에서 실행 (`python -m scripts.backfill_photo_dimensions`)
2. 웹 업로드 흐름에 dimensions 측정 + 전송 추가 (옵션 1번 코드)
3. `PortfolioChapterItems.tsx`의 ratio 초기화 + `<img width height>` 적용 (옵션 2번 코드)
4. Electron `queue.js`에도 sharp metadata 추가 (옵션 1번 Electron 부분)
5. (선택) CLS 측정으로 효과 검증

## iOS 작업 산출물과의 호환성

- **타입 호환:** `width`/`height`는 모두 Optional. 백필 전 사진/웹 업로드 사진은 null → 기존 onLoad 폴백 자동 적용. 마이그레이션이 모든 경로에 안전.
- **백엔드 응답 형태 동일:** `/portfolio/{user}/{slug}` 응답이 iOS와 웹 공통. 한 번 백필되면 양쪽 모두 즉시 혜택.
- **추가 마이그레이션 불필요:** v11에서 컬럼이 추가됐고, 백필도 동일 스크립트 사용.

## 잠재 이슈

1. **회전 사진 (`rotation` 필드)**
   - 사용자가 사진을 90°/270° 회전한 경우 width/height를 swap해 저장하거나, 클라이언트가 rotation을 보고 swap.
   - 백엔드 `rotation` 컬럼이 이미 있으므로 SingleFitPhoto/PortfolioJustifiedPhotoGrid에서 `rotation`이 90/270이면 `aspectRatio = height/width`로 뒤집기 권장. iOS도 후속 작업 필요.

2. **Cloudflare variant별 차원 차이**
   - DB의 width/height는 "원본" 차원이지만 클라이언트는 `grid`(800px)/`public`(3200px) variant 사용.
   - 비율은 동일하므로 영향 없음. 다만 `<img width height>` 속성에 원본 차원을 그대로 넣으면 큰 숫자가 됨 — `width/height`만 비율 유지하고, CSS로 실제 폭은 컨테이너에 맞춤. 또는 `style={{aspectRatio: w/h}}`로 대체 가능.
