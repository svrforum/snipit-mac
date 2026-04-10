# SnipIt for macOS

macOS 네이티브 화면 캡처 & 편집 도구.
스크린샷, GIF, MP4 녹화를 하나의 메뉴바 앱으로.

## 주요 기능

### 화면 캡처
- **전체 화면 캡처** — 즉시 캡처, 오버레이 없음
- **영역 선택 캡처** — 드래그로 원하는 영역 선택
- **활성 창 캡처** — 스마트 윈도우 감지, 클릭으로 캡처
- **스크롤 캡처** — 긴 페이지 캡처

### 화면 녹화
- **GIF 녹화** — 영역 선택 후 카운트다운, 최적화된 GIF 생성
- **MP4 녹화** — Retina 해상도, H.264/HEVC 코덱 지원
- 녹화 중 실시간 컨트롤 패널 (시간, 프레임, 정지/취소)
- 녹화 영역 빨간 테두리 표시

### 편집기
- 캡처 후 자동으로 편집기 열림
- **도구**: 선택, 펜, 화살표, 직선, 사각형, 원, 텍스트, 형광펜, 모자이크(블러), 자르기, OCR, 번호, 스텝, 코드블록
- **키보드 단축키**: V(선택), P(펜), A(화살표), L(직선), R(사각형), E(원), T(텍스트), H(형광펜), M(모자이크), C(자르기) — 한/영 모두 동작
- 색상 선택, 선 두께 조절
- 실행 취소/다시 실행 (Cmd+Z / Cmd+Shift+Z)
- 클립보드 복사, 파일 저장 (PNG/JPEG/PDF)
- **OCR** — 이미지에서 텍스트 인식 후 클립보드 복사 (한/영/일/중)
- **히스토리 사이드바** — 이전 캡처 목록, 클릭으로 편집기에서 열기

### 설정
- **일반** — 자동 실행, 캡처 사운드, 편집기 자동 열기, 클립보드 자동 복사
- **캡처** — 이미지 포맷 (PNG/JPEG/PDF), 딤 효과 투명도
- **녹화** — GIF (FPS, 최대 너비, 품질), MP4 (코덱), 최대 녹화 시간, 카운트다운, 커서 포함
- **단축키** — 모든 핫키 커스텀 가능 (클릭 후 키 입력)
- **테마** — 시스템/다크/라이트
- **정보** — 버전, 후원 링크

### 기타
- 메뉴바 상주 앱 (Dock 아이콘 없음)
- 글로벌 핫키 (Carbon 기반)
- 첫 실행 시 권한 요청 + 설정 창 자동 열림
- 한국어 기본, 영어 지원

## 기본 단축키

| 기능 | 단축키 |
|------|--------|
| 전체 화면 캡처 | `Ctrl+Opt+A` |
| 영역 선택 캡처 | `Cmd+Shift+C` |
| 활성 창 캡처 | `Ctrl+Opt+W` |
| 스크롤 캡처 | `Ctrl+Opt+D` |
| GIF 녹화 | `Ctrl+Opt+G` |
| MP4 녹화 | `Ctrl+Opt+V` |

모든 단축키는 설정에서 변경 가능합니다.

## 요구 사항

- macOS 14.0 (Sonoma) 이상
- 화면 녹화 권한

## 빌드

```bash
# xcodegen 설치
brew install xcodegen

# 프로젝트 생성
xcodegen generate

# 빌드
xcodebuild -project SnipIt.xcodeproj -scheme SnipIt -configuration Release build
```

## 의존성

- [Sparkle](https://github.com/sparkle-project/Sparkle) (2.0.0+) — 자동 업데이트
- 나머지 전부 Apple 네이티브 프레임워크

## 프로젝트 구조

```
SnipIt/
├── SnipItApp.swift              # @main, AppState, AppDelegate
├── Models/                      # CaptureMode, RecordingMode, AppSettings, HotkeyConfig, etc.
├── ViewModels/                  # Capture, Editor, Recording, History, Settings
├── Views/
│   ├── MenuBar/                 # 메뉴바 팝오버
│   ├── Capture/                 # 캡처 오버레이, 영역 선택, 스마트 감지
│   ├── Editor/                  # 에디터 캔버스, 도구 바, 액션 바
│   ├── Recording/               # 녹화 테두리, 컨트롤 패널
│   ├── History/                 # 캡처 히스토리
│   ├── Settings/                # 설정 탭 (일반/캡처/녹화/단축키/저장/테마/정보)
│   ├── Pin/                     # 핀 윈도우
│   ├── Onboarding/              # 온보딩
│   └── Components/              # Toast, Magnifier
├── Services/                    # ScreenCapture, Recording, Hotkey, History, OCR, Storage, Permission, Update
└── Utils/                       # ImageProcessor, KeyCodeMapping, NSWindow+Extensions
```

## 라이선스

MIT License

## 후원

[Buy Me a Coffee](https://buymeacoffee.com/svrforum)
