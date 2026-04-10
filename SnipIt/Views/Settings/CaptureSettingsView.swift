import SwiftUI

struct CaptureSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            HStack {
                Text("배경 어둡기")
                Slider(value: $viewModel.settings.dimmingOpacity, in: 0...1, step: 0.05)
                Text("\(Int(viewModel.settings.dimmingOpacity * 100))%")
                    .frame(width: 40, alignment: .trailing)
                    .monospacedDigit()
            }

            Picker("기본 이미지 형식", selection: $viewModel.settings.defaultImageFormat) {
                Text("PNG").tag(ImageFormat.png)
                Text("JPG").tag(ImageFormat.jpg)
                Text("PDF").tag(ImageFormat.pdf)
            }

            Toggle("커서 포함", isOn: $viewModel.settings.includeCursor)
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.settings) {
            viewModel.save()
        }
    }
}
