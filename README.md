# SnipIt for macOS

<p align="center">
  <strong>macOS 네이티브 화면 캡처 & 녹화 & 편집 도구</strong><br>
  스크린샷, GIF, MP4를 하나의 메뉴바 앱으로.
</p>

<p align="center">
  <a href="https://github.com/svrforum/snipit-mac/releases/latest">
    <img src="https://img.shields.io/github/v/release/svrforum/snipit-mac?style=flat-square" alt="Release">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/github/license/svrforum/snipit-mac?style=flat-square" alt="License">
  </a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue?style=flat-square" alt="macOS 14.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square" alt="Swift 5.9">
</p>

---

## 주요 기능

### 화면 캡처
- **전체 화면** — 즉시 캡처, 오버레이 없이 바로 완료
- **영역 선택** — 드래그로 원하는 영역만 정확하게 캡처
- **활성 창 감지** — 마우스 위치의 윈도우를 자동 감지, 클릭으로 캡처
- 캡처 후 자동 클립보드 복사 + 편집기 열림

### GIF / MP4 녹화
- **영역 선택 후 녹화** — 원하는 영역만 녹화
- **3, 2, 1 카운트다운** — 준비할 시간 제공
- **실시간 컨트롤 패널** — 경과 시간, 프레임 수 표시, 정지/취소 버튼
- **녹화 영역 빨간 테두리** — 녹화 범위 시각적 표시
- **GIF 최적화** — 해상도, FPS, 품질 세부 설정 가능
- **MP4** — Retina 2x 해상도, H.264/HEVC 코덱 선택

### 편집기
- 캡처 즉시 편집기 자동 열림 (ESC로 바로 닫기)
- **14종 도구** — 선택, 펜, 화살표, 직선, 사각형, 원, 텍스트, 형광펜, 모자이크, 자르기, OCR, 번호, 스텝, 코드블록
- **키보드 단축키** — 한글/영문 모두 동작 (하드웨어 키코드 기반)
- **모자이크(블러)** — 드래그 영역 정확하게 모자이크 처리
- **OCR** — Vision 프레임워크 기반 텍스트 인식 (한/영/일/중), 클립보드 복사
- **히스토리 사이드바** — 이전 캡처 목록, 클릭으로 편집기에서 열기
- 실행 취소/다시 실행 (Cmd+Z / Cmd+Shift+Z)
- 파일 저장 (PNG/JPEG/PDF)
- 이미지 경계선 + 그림자로 편집 영역 명확하게 표시

### 설정
| 탭 | 내용 |
|----|------|
| 일반 | 자동 실행, 캡처 사운드, 편집기 자동 열기, 클립보드 자동 복사 |
| 캡처 | 이미지 포맷, 딤 효과 투명도 |
| 녹화 | GIF (FPS/최대 너비/품질), MP4 (코덱), 최대 시간, 카운트다운, 커서 포함 |
| 단축키 | 모든 핫키 커스텀 (클릭 후 키 입력으로 변경) |
| 테마 | 시스템 / 다크 / 라이트 |
| 정보 | 버전, 후원 링크 |

## 기본 단축키

| 기능 | 단축키 |
|------|--------|
| 전체 화면 캡처 | `Cmd+Shift+A` |
| 영역 선택 캡처 | `Cmd+Shift+C` |
| 활성 창 캡처 | `Cmd+Shift+W` |
| 스크롤 캡처 | `Cmd+Shift+D` |
| GIF 녹화 | `Cmd+Shift+G` |
| MP4 녹화 | `Cmd+Shift+V` |

모든 단축키는 설정에서 변경 가능합니다.

### 편집기 도구 단축키

| 키 | 도구 | 키 | 도구 |
|----|------|----|------|
| V | 선택 | T | 텍스트 |
| P | 펜 | H | 형광펜 |
| A | 화살표 | M | 모자이크 |
| L | 직선 | C | 자르기 |
| R | 사각형 | ESC | 닫기 |
| E | 원 | | |

한글 입력 상태에서도 동작합니다.

## 설치

### DMG 다운로드
[최신 릴리즈 다운로드](https://github.com/svrforum/snipit-mac/releases/latest)

1. DMG 열기
2. SnipIt.app → Applications 폴더로 드래그
3. 실행 → 화면 녹화 권한 허용
4. 메뉴바 가위(✂️) 아이콘으로 사용

### 소스에서 빌드

```bash
# xcodegen 설치
brew install xcodegen

# 프로젝트 생성 & 빌드
xcodegen generate
xcodebuild -project SnipIt.xcodeproj -scheme SnipIt -configuration Release build
```

## 요구 사항

- macOS 14.0 (Sonoma) 이상
- 화면 녹화 권한

## 기술 스택

| 항목 | 기술 |
|------|------|
| 언어 | Swift 5.9+ |
| UI | SwiftUI + AppKit |
| 캡처 | ScreenCaptureKit |
| 녹화 | SCStream + AVAssetWriter + ImageIO (GIF) |
| OCR | Vision Framework |
| 핫키 | Carbon HIToolbox |
| 업데이트 | Sparkle 2.0 |
| 아키텍처 | MVVM + @Observable + Swift Concurrency |

## 프로젝트 구조

```
SnipIt/
├── SnipItApp.swift              # @main, AppState, AppDelegate
├── Models/                      # 6개 모델
├── ViewModels/                  # 5개 뷰모델
├── Views/
│   ├── MenuBar/                 # 메뉴바 팝오버
│   ├── Capture/                 # 캡처 오버레이, 영역 선택, 스마트 감지
│   ├── Editor/                  # 편집기 캔버스, 도구 바, 액션 바
│   ├── Recording/               # 녹화 테두리, 컨트롤 패널
│   ├── History/                 # 캡처 히스토리
│   ├── Settings/                # 7개 설정 탭
│   └── Components/              # Toast
├── Services/                    # 9개 서비스
└── Utils/                       # ImageProcessor, KeyCodeMapping, NSWindow+Extensions
```

## 의존성

- [Sparkle](https://github.com/sparkle-project/Sparkle) (2.0.0+) — 자동 업데이트
- 나머지 전부 Apple 네이티브 프레임워크

## 후원

이 프로젝트가 유용하다면 커피 한 잔 사주세요!

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-svrforum-yellow?style=flat-square&logo=buy-me-a-coffee)](https://buymeacoffee.com/svrforum)

## 라이선스

[MIT License](LICENSE) - 자유롭게 사용, 수정, 배포할 수 있습니다.
