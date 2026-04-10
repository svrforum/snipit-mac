import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    @Environment(\.dismiss) private var dismiss

    private let permissionService = PermissionService()

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                welcomeStep
                    .tag(0)

                permissionStep
                    .tag(1)

                shortcutsStep
                    .tag(2)
            }
            .tabViewStyle(.automatic)

            Divider()

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("이전") {
                        withAnimation { currentStep -= 1 }
                    }
                }

                Spacer()

                if currentStep < 2 {
                    Button("다음") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("시작하기") {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 480, height: 380)
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "scissors")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("SnipIt에 오신 것을 환영합니다")
                .font(.title2)
                .fontWeight(.semibold)

            Text("macOS를 위한 강력한 화면 캡처 도구입니다.\n스크린샷, GIF, 동영상을 손쉽게 캡처하세요.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()
        }
        .padding()
    }

    // MARK: - Permission Step

    private var permissionStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("화면 녹화 권한")
                .font(.title2)
                .fontWeight(.semibold)

            Text("화면을 캡처하려면 화면 녹화 권한이 필요합니다.\n시스템 설정에서 권한을 허용해주세요.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button("권한 요청하기") {
                permissionService.requestScreenRecordingPermission()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }

    // MARK: - Shortcuts Step

    private var shortcutsStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "keyboard")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("단축키")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                shortcutRow("전체 화면", shortcut: "⌃⌥A")
                shortcutRow("영역 선택", shortcut: "⌘⇧C")
                shortcutRow("활성 창", shortcut: "⌃⌥W")
                shortcutRow("GIF 녹화", shortcut: "⌃⌥G")
                shortcutRow("MP4 녹화", shortcut: "⌃⌥V")
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Shortcut Row

    private func shortcutRow(_ label: String, shortcut: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}
