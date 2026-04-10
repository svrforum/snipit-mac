# SnipIt Mac — Claude Code Context

## 프로젝트 개요

macOS 네이티브 화면 캡처 & 편집 도구. Windows 버전(svrforum/snipit)의 전체 기능 macOS 포팅 + 신규 기능.

- **레포**: https://github.com/svrforum/snipit-mac
- **타겟**: macOS 14.0+ (Sonoma)
- **스택**: Swift 5.9+ / SwiftUI + AppKit (최소) / ScreenCaptureKit
- **아키텍처**: MVVM + @Observable + Swift Concurrency
- **배포**: Direct Distribution (DMG + Notarization)
- **디자인**: Toss + Apple UI

## 현재 상태

**구현 100% 완료 (50 Swift 파일), Xcode 빌드 미완료.**

### 남은 작업 (Xcode 설치 후 순서대로)

1. `xcodegen generate` — .xcodeproj 생성
2. `open SnipIt.xcodeproj` — Xcode에서 열기
3. Signing & Capabilities → Team을 Developer ID로 변경
4. ⌘B 빌드 → 컴파일 에러 수정 (swiftc 검증은 통과했으나 전체 빌드 시 추가 이슈 가능)
5. ⌘U 테스트 실행
6. 앱 아이콘 제작 → Assets.xcassets/AppIcon.appiconset/
7. DMG 패키징 (`brew install create-dmg`)
8. GitHub Release 생성
9. appcast.xml 생성 (Sparkle 자동 업데이트용)

## 문서

- **디자인 스펙**: `docs/superpowers/specs/2026-04-10-snipit-mac-design.md`
- **구현 계획**: `docs/superpowers/plans/2026-04-10-snipit-mac.md`

## 프로젝트 구조

```
SnipIt/
├── SnipItApp.swift              # @main, AppState, 전체 앱 연결
├── Models/                      # 6개: CaptureMode, RecordingMode, AppSettings, HotkeyConfig, CaptureHistoryItem, Annotation
├── ViewModels/                  # 5개: Capture, Editor, Recording, History, Settings
├── Views/
│   ├── MenuBar/                 # 메뉴바 팝오버
│   ├── Capture/                 # 캡처 오버레이, 스마트 감지, 영역 선택
│   ├── Editor/                  # 에디터 캔버스, 플로팅 툴바, 액션바
│   ├── Recording/               # 녹화 테두리, 컨트롤 패널
│   ├── History/                 # 캡처 히스토리 그리드
│   ├── Settings/                # 7개 탭 (일반/캡처/녹화/단축키/저장/테마/정보)
│   ├── Pin/                     # 핀 윈도우
│   ├── Onboarding/              # 온보딩 플로우
│   └── Components/              # ToastView, MagnifierView
├── Services/                    # 9개: ScreenCapture, ScrollCapture, Recording, Hotkey, History, OCR, Storage, Permission, Update
├── Utils/                       # ImageProcessor, KeyCodeMapping, NSWindow+Extensions
└── Resources/
    └── Localizable.xcstrings    # 한국어/영어 다국어

SnipItTests/
├── Models/AppSettingsTests.swift
└── Services/StorageServiceTests.swift, HistoryServiceTests.swift
```

## 빌드

```bash
# 프로젝트 생성 (xcodegen 필요: brew install xcodegen)
xcodegen generate

# Xcode에서 빌드
open SnipIt.xcodeproj
# ⌘B 빌드, ⌘R 실행, ⌘U 테스트

# CLI 빌드 (Xcode.app 필요)
xcodebuild -project SnipIt.xcodeproj -scheme SnipIt -configuration Release build
```

## 의존성

- **Sparkle** (2.0.0+) — 자동 업데이트 (SPM)
- 나머지 전부 Apple 네이티브 프레임워크

## 주요 설계 결정

- **MenuBarExtra** 메뉴바 상주 앱 (LSUIElement=YES, Dock 아이콘 없음)
- **캡처 후 에디터 직행** — 캡처 → 자동 클립보드 복사 → 에디터 열림, ESC로 바로 닫기 가능
- **Carbon 글로벌 핫키** — macOS에서 글로벌 핫키 유일한 공식 방법
- **파일 기반 설정** — UserDefaults 대신 ~/Library/Application Support/SnipIt/Settings.json
- **ImageIO GIF 인코딩** — CGImageDestination 사용, 외부 라이브러리 없음
- **기본 단축키 ⌃⌥ 계열** — macOS 기본 ⌘⇧3/4/5와 충돌 회피
