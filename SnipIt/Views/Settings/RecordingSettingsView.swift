import SwiftUI

struct RecordingSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            // MARK: - GIF 설정

            Section {
                Picker("프레임 레이트", selection: $viewModel.settings.recordingFPS) {
                    Text("10 FPS (작은 파일)").tag(RecordingFPS.fifteen)
                    Text("15 FPS (권장)").tag(RecordingFPS.thirty)
                    Text("30 FPS (부드러움)").tag(RecordingFPS.sixty)
                }

                Picker("GIF 최대 너비", selection: $viewModel.settings.gifMaxWidth) {
                    Text("320px (최소)").tag(GifMaxWidth.w320)
                    Text("480px (권장)").tag(GifMaxWidth.w480)
                    Text("640px").tag(GifMaxWidth.w640)
                    Text("800px").tag(GifMaxWidth.w800)
                    Text("원본 크기 ⚠️").tag(GifMaxWidth.original)
                }

                Picker("GIF 품질", selection: $viewModel.settings.gifQuality) {
                    Text("원본 (큰 파일)").tag(GifQuality.original)
                    Text("프레임 스킵 (작은 파일)").tag(GifQuality.skipFrames)
                    Text("스킵 + 축소 (최소)").tag(GifQuality.skipFramesHalfSize)
                }

                Text("GIF는 최대 30초, 300프레임으로 제한됩니다.\n너비가 클수록 파일 크기가 커지고 인코딩이 느려집니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("GIF 녹화")
            }

            // MARK: - MP4 설정

            Section {
                Picker("비디오 코덱", selection: $viewModel.settings.videoCodec) {
                    Text("H.264 (호환성)").tag(VideoCodec.h264)
                    Text("HEVC (작은 파일)").tag(VideoCodec.hevc)
                }

                Text("MP4는 Retina(2x) 해상도로 녹화됩니다.\nHEVC는 파일이 작지만 일부 기기에서 재생 불가할 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("MP4 녹화")
            }

            // MARK: - 공통 설정

            Section {
                Picker("최대 녹화 시간", selection: $viewModel.settings.maxRecordingDuration) {
                    Text("10초").tag(TimeInterval(10))
                    Text("30초").tag(TimeInterval(30))
                    Text("60초").tag(TimeInterval(60))
                    Text("120초").tag(TimeInterval(120))
                    Text("300초 (5분)").tag(TimeInterval(300))
                }

                Toggle("녹화 전 카운트다운 (3, 2, 1)", isOn: $viewModel.settings.showCountdown)

                Toggle("마우스 커서 포함", isOn: $viewModel.settings.showCursorInRecording)
            } header: {
                Text("공통")
            }

            // MARK: - 주의사항

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("GIF는 파일 크기가 매우 클 수 있습니다", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Label("긴 녹화는 MP4를 권장합니다", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("녹화 중 다른 앱 전환 시 해당 화면도 캡처됩니다", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("주의사항")
            }
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.settings) {
            viewModel.save()
        }
    }
}
