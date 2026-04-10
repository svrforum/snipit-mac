import SwiftUI

// MARK: - HistoryView

struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("캡처 히스토리")
                    .font(.headline)

                Spacer()

                if !viewModel.items.isEmpty {
                    Button("전체 삭제", role: .destructive) {
                        viewModel.clearAll()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .font(.caption)
                }
            }
            .padding()

            Divider()

            // Content
            if viewModel.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.items) { item in
                            HistoryItemView(item: item, viewModel: viewModel)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("캡처 히스토리가 비어있습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - HistoryItemView

struct HistoryItemView: View {
    let item: CaptureHistoryItem
    let viewModel: HistoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Thumbnail
            Group {
                if let thumbnail = viewModel.loadThumbnail(for: item) {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Dimensions
            Text("\(item.width) × \(item.height)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Relative timestamp
            Text(item.timestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .onTapGesture(count: 2) {
            openInEditor()
        }
        .contextMenu {
            Button("편집기에서 열기") {
                openInEditor()
            }

            Divider()

            Button("삭제", role: .destructive) {
                viewModel.delete(item)
            }
        }
    }

    // MARK: - Actions

    private func openInEditor() {
        // Handled via EditorWindow's history sidebar
    }
}
