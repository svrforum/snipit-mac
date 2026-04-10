import SwiftUI

struct RecordingSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Picker("프레임 레이트", selection: $viewModel.settings.recordingFPS) {
                Text("15 FPS").tag(RecordingFPS.fifteen)
                Text("30 FPS").tag(RecordingFPS.thirty)
                Text("60 FPS").tag(RecordingFPS.sixty)
            }

            Picker("GIF 품질", selection: $viewModel.settings.gifQuality) {
                Text("원본").tag(GifQuality.original)
                Text("프레임 스킵").tag(GifQuality.skipFrames)
                Text("프레임 스킵 + 축소").tag(GifQuality.skipFramesHalfSize)
            }

            Picker("비디오 코덱", selection: $viewModel.settings.videoCodec) {
                Text("H.264").tag(VideoCodec.h264)
                Text("HEVC").tag(VideoCodec.hevc)
            }

            Picker("최대 녹화 시간", selection: $viewModel.settings.maxRecordingDuration) {
                Text("30초").tag(TimeInterval(30))
                Text("60초").tag(TimeInterval(60))
                Text("120초").tag(TimeInterval(120))
                Text("180초").tag(TimeInterval(180))
            }
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.settings) {
            viewModel.save()
        }
    }
}
