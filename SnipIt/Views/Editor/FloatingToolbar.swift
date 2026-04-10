import SwiftUI

struct FloatingToolbar: View {
    @Bindable var viewModel: EditorViewModel

    private let drawingTools: [EditorTool] = [.select, .pen, .arrow, .line, .rectangle, .ellipse]
    private let markupTools: [EditorTool] = [.text, .highlight, .blur, .crop]
    private let annotationTools: [EditorTool] = [.number, .step, .codeBlock]
    private let strokeWidths: [CGFloat] = [1, 2, 3, 5, 8]

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                ForEach(drawingTools) { tool in
                    toolButton(tool)
                }

                separator

                ForEach(markupTools) { tool in
                    toolButton(tool)
                }

                separator

                ForEach(annotationTools) { tool in
                    toolButton(tool)
                }

                separator

                // Stroke width
                Menu {
                    ForEach(strokeWidths, id: \.self) { width in
                        Button {
                            viewModel.strokeWidth = width
                        } label: {
                            HStack {
                                Text("\(Int(width)) px")
                                if viewModel.strokeWidth == width {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "lineweight")
                        .font(.system(size: 13))
                        .frame(width: 26, height: 26)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 26)
                .help("선 두께")

                // Color picker
                ColorPicker("", selection: $viewModel.strokeColor)
                    .labelsHidden()
                    .frame(width: 26, height: 26)
                    .help("색상")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var separator: some View {
        Divider()
            .frame(height: 18)
            .padding(.horizontal, 2)
    }

    // MARK: - Tool Button

    @ViewBuilder
    private func toolButton(_ tool: EditorTool) -> some View {
        Button {
            viewModel.currentTool = tool
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: 13))
                .frame(width: 26, height: 26)
                .foregroundColor(viewModel.currentTool == tool ? .accentColor : .primary)
                .background(
                    viewModel.currentTool == tool
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                )
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
        .help(tool.shortcutKey != nil ? "\(tool.label) (\(tool.shortcutKey!))" : tool.label)
    }
}
