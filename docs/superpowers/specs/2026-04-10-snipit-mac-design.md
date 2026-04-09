# SnipIt Mac — Design Specification

## Overview

macOS 네이티브 화면 캡처 & 편집 도구. 기존 Windows 버전(svrforum/snipit)의 전체 기능을 macOS로 포팅하면서 성능/기능 개선을 포함한 완전 재작성.

- **레포**: https://github.com/svrforum/snipit-mac
- **타겟**: macOS 14.0+ (Sonoma)
- **스택**: Swift 5.9+ / SwiftUI + AppKit (최소) / ScreenCaptureKit
- **아키텍처**: MVVM + @Observable + Swift Concurrency
- **배포**: Direct Distribution (DMG + Notarization), GitHub Releases
- **디자인 언어**: Toss + Apple UI (미니멀, 클린, 부드러운 애니메이션)

---

## 기능 매트릭스

### 기존 기능 (Windows → macOS 포팅)

| 기능 | Windows 구현 | macOS 구현 |
|------|-------------|-----------|
| 전체 화면 캡처 | Win32 BitBlt | SCScreenshotManager.captureImage |
| 활성 창 캡처 | GetForegroundWindow + DwmGetWindowAttribute | SCShareableContent.windows |
| 영역 선택 캡처 | WPF Overlay + CopyFromScreen | NSWindow overlay + SCScreenshotManager |
| GIF 녹화 | Timer + CopyFromScreen + AnimatedGif | SCStream → CGImage 시퀀스 |
| 이미지 에디터 | WPF Canvas + DrawingVisual | SwiftUI Canvas + Annotation 모델 |
| 글로벌 단축키 | Win32 RegisterHotKey | Carbon RegisterEventHotKey |
| 시스템 트레이 | NotifyIcon (WinForms) | MenuBarExtra (SwiftUI) |
| OCR | Windows.Media.Ocr | Vision VNRecognizeTextRequest |
| 캡처 히스토리 | 파일 기반 JSON 인덱스 | 동일 (Codable JSON) |
| 다국어 | Dictionary 기반 (한/영) | String Catalog .xcstrings (시스템 로케일 자동) |
| 토스트 알림 | WPF ToastNotification | SwiftUI ToastView |
| 설정 | AppSettingsConfig + Registry | Codable JSON 파일 |

### 신규 기능

| 기능 | 설명 |
|------|------|
| 스크롤 캡처 | 연속 캡처 + Vision 프레임워크 이미지 스티칭 |
| MP4 녹화 | SCStream → AVAssetWriter, H.264/HEVC 하드웨어 가속 |
| 스마트 윈도우 감지 | 마우스 아래 창 자동 인식 + 하이라이트, 클릭으로 캡처 |
| 핀 윈도우 | 캡처 이미지를 항상 위 창으로 고정, 투명도 조절 |
| 번호 매기기 도구 | 자동 증가 원형 번호 어노테이션 |
| 스텝 표시 도구 | 순서 설명용 말풍선 어노테이션 |
| 코드 블록 도구 | 모노스페이스 배경 박스 어노테이션 |
| 캡처 → 에디터 직행 | 캡처 즉시 에디터 열림 + 자동 클립보드 복사 |
| Sparkle 자동 업데이트 | Direct Distribution용 자동 업데이트 |
| 온보딩 플로우 | 첫 실행 시 권한 요청 + 기능 안내 |

---

## 아키텍처

### 전체 구조

```
┌─────────────┬───────────────┬───────────────────────┐
│   Views     │  ViewModels   │      Services         │
│  (SwiftUI)  │ (@Observable) │  (Swift Concurrency)  │
├─────────────┼───────────────┼───────────────────────┤
│ MenuBarView │ CaptureVM     │ ScreenCaptureService  │
│ OverlayWin  │ EditorVM      │ ScrollCaptureService  │
│ EditorView  │ SettingsVM    │ RecordingService      │
│ SettingsView│ HistoryVM     │ HotkeyService         │
│ HistoryView │ RecordingVM   │ HistoryService        │
│ PinWindow   │               │ OCRService            │
│ ToastView   │               │ StorageService        │
│ Onboarding  │               │ PermissionService     │
│             │               │ UpdateService         │
└─────────────┴───────────────┴───────────────────────┘
         │              │                │
         ▼              ▼                ▼
┌─────────────────────────────────────────────────────┐
│              macOS Frameworks                        │
│  ScreenCaptureKit · AVFoundation · Vision · AppKit  │
│  Carbon (핫키) · UserNotifications · Sparkle        │
└─────────────────────────────────────────────────────┘
```

### 핵심 결정사항

- **@Observable 매크로**: ObservableObject/Published 대신 macOS 14+ 네이티브
- **Swift Concurrency**: 모든 비동기 작업은 async/await + Actor
- **의존성 주입**: SwiftUI Environment를 통한 서비스 주입
- **AppKit 최소 사용**: 캡처 오버레이(NSWindow), 메뉴바(NSStatusItem 폴백), 글로벌 핫키(Carbon) 한정

---

## 캡처 시스템

### 캡처 플로우

```
사용자 단축키 입력
       │
       ▼
PermissionService: 화면 녹화 권한 체크
       │
       ▼
ScreenCaptureService: 캡처 모드별 실행
       │
       ├─→ 자동 클립보드 복사 (항상, 백그라운드)
       │
       └─→ 에디터 즉시 열림 (캡처 이미지 로드)
                │
                ├─ 수정 → 완료 → 저장/복사(덮어쓰기)/공유
                │
                └─ ESC → 닫기 (이미 클립보드에 복사된 상태)
```

설정에서 "캡처 후 에디터 자동 열기" 옵션 제공. 비활성화 시 사일런트 모드(클립보드만 복사).

### 캡처 모드

| 모드 | 구현 | API |
|------|------|-----|
| 전체 화면 | SCDisplay 캡처 | SCScreenshotManager.captureImage |
| 활성 창 / 스마트 감지 | 마우스 아래 SCWindow 감지 + 하이라이트 | SCShareableContent.windows |
| 영역 선택 | NSWindow 풀스크린 오버레이 + 드래그 | AppKit NSWindow (level: .screenSaver) |
| 스크롤 캡처 | 연속 캡처 + Vision 이미지 매칭/스티칭 | ScreenCaptureKit + VNFeaturePrintObservation |

### 영역 캡처 오버레이 UX (스마트 감지 모드)

- 마우스 아래 창을 자동 감지하여 파란색 테두리 하이라이트
- 클릭으로 해당 창 캡처
- 드래그로 자유 영역 선택 전환
- 선택 중 크기 표시 (픽셀)
- Space로 전체 화면 전환
- ESC로 취소

---

## 녹화 시스템

### 구현

```
SCStream (ScreenCaptureKit)
       │
       ├─→ MP4: AVAssetWriter (H.264/HEVC, 하드웨어 가속)
       │
       └─→ GIF: CMSampleBuffer → CGImage 프레임 수집
            중복 프레임 스킵 → AnimatedGIF 인코딩
```

### 설정

- 프레임레이트: 15 / 30 / 60 fps
- 최대 녹화 시간: 30 / 60 / 120 / 180초
- GIF 품질: 원본 / 스킵프레임 / 스킵프레임+하프사이즈
- MP4 코덱: H.264 (호환성) / HEVC (품질)

### 기존 대비 개선

- SCStream 기반으로 CopyFromScreen 대비 성능 대폭 향상
- MP4는 VideoToolbox 하드웨어 인코더 활용 → CPU 부하 최소
- 녹화 중 빨간 테두리 + 컨트롤 창 (중지/일시정지/경과시간)

---

## 이미지 에디터

### 레이아웃: 플로팅 툴바 (Apple 스타일)

- 캔버스 위 반투명 드래그 가능 툴바
- 하단 액션바: ESC 닫기 | 실행취소/재실행 | 📌 핀 | 🔤 OCR | 📋 복사 | 💾 저장 | 완료
- 에디터 열릴 때 "✅ 클립보드에 복사됨" 토스트 표시

### 캔버스 레이어 구조

```
Layer 0: 원본 이미지 (불변)
Layer 1: 커밋된 어노테이션 오브젝트들
Layer 2: 현재 그리기 중인 오브젝트 (미리보기)
```

SwiftUI Canvas 뷰로 렌더링. 각 어노테이션은 Annotation 프로토콜 준수 struct.

### 도구 목록

| 도구 | 상태 | 설명 |
|------|------|------|
| 펜 (자유 그리기) | 포팅 | 프리핸드 드로잉 |
| 화살표 | 포팅 | 방향 표시 |
| 직선 | 포팅 | 가이드라인 |
| 사각형 | 포팅 | 영역 강조 |
| 원/타원 | 포팅 | 영역 강조 |
| 텍스트 | 포팅 | 폰트/크기/색상 커스텀 |
| 형광펜 | 포팅 | 반투명 하이라이트 |
| 블러/모자이크 | 포팅 | 16px 블록 모자이크 |
| 자르기 | 포팅 | 이미지 트림 |
| OCR | 포팅 | Vision 기반, 텍스트 영역 선택 |
| 번호 매기기 | 신규 | 자동 증가 원형 번호 |
| 스텝 표시 | 신규 | 순서 설명용 말풍선 |
| 코드 블록 | 신규 | 모노스페이스 배경 박스 |

### 공통 속성

- 색상 선택 (컬러 피커)
- 선 두께 조절
- Undo/Redo (Swift UndoManager)
- 내보내기: PNG, JPG, PDF, 클립보드

---

## 앱 라이프사이클

### 메뉴바 상주 앱

- MenuBarExtra (SwiftUI) 사용
- Dock 아이콘 없음 (LSUIElement = true)
- 에디터/설정 열 때 임시 활성화
- 메뉴바 팝오버: 캡처 4종 그리드 + 녹화 2종 + 최근 캡처 썸네일

### 글로벌 단축키

Carbon API (RegisterEventHotKey) 사용.

기본 단축키 (macOS 기본 ⌘⇧3/4/5와 충돌 회피):
- ⌃⌥A: 전체 화면 캡처
- ⌃⌥S: 영역 선택 (스마트 감지)
- ⌃⌥W: 활성 창 캡처
- ⌃⌥D: 스크롤 캡처
- ⌃⌥G: GIF 녹화 시작/중지
- ⌃⌥V: MP4 녹화 시작/중지

모두 설정에서 커스터마이징 가능. 사용자가 원하면 macOS 기본 단축키를 시스템 설정에서 비활성화 후 ⌘⇧ 계열로 매핑 가능.

### 권한 관리

| 권한 | 필수 여부 | 용도 |
|------|----------|------|
| 화면 녹화 (Screen Recording) | 필수 | ScreenCaptureKit |
| 접근성 (Accessibility) | 선택 | 스크롤 캡처 자동화 |
| 알림 (Notifications) | 선택 | 토스트 알림 |

첫 실행 온보딩: 환영 → 화면 녹화 권한 요청 → 단축키 안내 → 완료.

---

## 데이터 저장

```
~/Library/Application Support/SnipIt/
├── Settings.json          (앱 설정, Codable)
├── history/
│   ├── index.json         (히스토리 인덱스)
│   ├── images/            (원본 PNG)
│   └── thumbs/            (JPEG 썸네일 160x100)
└── recordings/            (GIF/MP4 임시저장)
```

- UserDefaults 대신 파일 기반 → 백업/이전 용이
- 히스토리: 최대 100개, FIFO 자동 정리
- 설정: Codable struct → JSON 직렬화

---

## UI/UX 디자인

### 테마

- 시스템 연동 + 수동 전환 (시스템/다크/라이트)
- Toss + Apple 디자인 언어: 미니멀, 넓은 여백, 둥근 모서리, 부드러운 애니메이션
- 반투명/블러 효과 (NSVisualEffectView / .ultraThinMaterial)

### 핵심 화면

1. **메뉴바 팝오버**: 캡처 4종 + 녹화 2종 그리드, 최근 캡처 썸네일, 설정 접근
2. **에디터**: 플로팅 툴바 + 하단 액션바, 캡처 직후 자동 열림
3. **설정**: Apple 시스템 설정 스타일 탭 (일반/캡처/녹화/단축키/저장/테마)
4. **핀 윈도우**: 항상 위, 리사이즈 가능, 투명도 조절
5. **온보딩**: 3단계 (환영 → 권한 → 단축키)

### 다국어

- String Catalog (.xcstrings) 기반
- 시스템 로케일 자동 감지
- 초기 지원: 한국어, 영어
- 커뮤니티 번역 구조로 확장 용이

---

## 설정 항목

### 일반
- 시작 시 자동 실행 (Login Items)
- 캡처 사운드 재생
- 캡처 후 에디터 자동 열기 (기본: 켜짐)
- 자동 클립보드 복사 (기본: 켜짐)
- 언어 선택

### 캡처
- 돋보기 표시 위치
- 딤 오버레이 투명도 (0-100%)
- 기본 이미지 포맷 (PNG/JPG/PDF)
- 커서 포함 여부

### 녹화
- 프레임레이트 (15/30/60 fps)
- GIF 품질 프리셋
- MP4 코덱 (H.264/HEVC)
- 최대 녹화 시간

### 단축키
- 6개 기본 단축키 모두 커스터마이징
- 충돌 감지 + 경고

### 저장
- 기본 저장 폴더
- 파일 이름 패턴

### 테마
- 시스템 / 다크 / 라이트

---

## 의존성

| 라이브러리 | 용도 | 비고 |
|-----------|------|------|
| Sparkle | 자동 업데이트 | Direct Distribution 필수 |


최소 의존성 원칙. GIF 인코딩은 Apple 네이티브 ImageIO 프레임워크(CGImageDestination)로 구현. 나머지도 모두 Apple 네이티브 프레임워크.

---

## 빌드 & 배포

- Xcode 15+ 빌드
- Developer ID 코드 서명
- Apple Notarization
- DMG 패키징
- GitHub Releases 배포
- Sparkle appcast.xml로 자동 업데이트

---

## 프로젝트 파일 구조

```
SnipIt/
├── SnipItApp.swift
├── Info.plist
├── SnipIt.entitlements
├── Assets.xcassets/
├── Models/
│   ├── CaptureMode.swift
│   ├── RecordingMode.swift
│   ├── Annotation.swift
│   ├── HotkeyConfig.swift
│   ├── AppSettings.swift
│   └── CaptureHistoryItem.swift
├── ViewModels/
│   ├── CaptureViewModel.swift
│   ├── EditorViewModel.swift
│   ├── RecordingViewModel.swift
│   ├── HistoryViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── MenuBar/
│   │   └── MenuBarView.swift
│   ├── Capture/
│   │   ├── CaptureOverlayWindow.swift
│   │   ├── SmartDetectionView.swift
│   │   └── RegionSelectionView.swift
│   ├── Editor/
│   │   ├── EditorWindow.swift
│   │   ├── EditorCanvasView.swift
│   │   ├── FloatingToolbar.swift
│   │   └── ActionBar.swift
│   ├── Recording/
│   │   ├── RecordingBorderView.swift
│   │   └── RecordingControlView.swift
│   ├── History/
│   │   └── HistoryView.swift
│   ├── Settings/
│   │   ├── SettingsWindow.swift
│   │   ├── GeneralSettingsView.swift
│   │   ├── CaptureSettingsView.swift
│   │   ├── RecordingSettingsView.swift
│   │   ├── HotkeySettingsView.swift
│   │   ├── StorageSettingsView.swift
│   │   └── ThemeSettingsView.swift
│   ├── Pin/
│   │   └── PinWindow.swift
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   └── Components/
│       ├── ToastView.swift
│       └── MagnifierView.swift
├── Services/
│   ├── ScreenCaptureService.swift
│   ├── ScrollCaptureService.swift
│   ├── RecordingService.swift
│   ├── HotkeyService.swift
│   ├── HistoryService.swift
│   ├── OCRService.swift
│   ├── StorageService.swift
│   ├── PermissionService.swift
│   └── UpdateService.swift
├── Utils/
│   ├── ImageProcessor.swift
│   ├── KeyCodeMapping.swift
│   └── NSWindow+Extensions.swift
└── Resources/
    ├── Localizable.xcstrings
    └── Sounds/
        └── capture.aiff
```
