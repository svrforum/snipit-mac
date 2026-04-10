import SwiftUI

struct FloatingToolbar: View {
    @Bindable var viewModel: EditorViewModel

    private let drawingTools: [EditorTool] = [.select, .pen, .arrow, .line, .rectangle, .ellipse]
    private let markupTools: [EditorTool] = [.text, .highlight, .blur, .crop]
    private let annotationTools: [EditorTool] = [.number, .step, .codeBlock]
    private let strokeWidths: [CGFloat] = [1, 2, 3, 5, 8]

    var body: some View {
        HStack(spacing: 6) {
            // Drawing tools group
            ForEach(drawingTools) { tool in
                toolButton(tool)
            }

            Divider()
                .frame(height: 20)

            // Markup tools group
            ForEach(markupTools) { tool in
                toolButton(tool)
            }

            Divider()
                .frame(height: 20)

            // Annotation tools group
            ForEach(annotationTools) { tool in
                toolButton(tool)
            }

            Divider()
                .frame(height: 20)

            // Color picker
            ColorPicker("", selection: $viewModel.strokeColor)
                .labelsHidden()
                .frame(width: 24, height: 24)

            // Stroke width menu
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
                    .font(.system(size: 14))
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
    }

    // MARK: - Tool Button

    @ViewBuilder
    private func toolButton(_ tool: EditorTool) -> some View {
        Button {
            viewModel.currentTool = tool
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .foregroundColor(viewModel.currentTool == tool ? .accentColor : .primary)
                .background(
                    viewModel.currentTool == tool
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                )
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(tool.label)
    }
}
