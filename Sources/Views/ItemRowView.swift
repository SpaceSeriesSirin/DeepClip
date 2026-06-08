import SwiftUI

/// A single row in the item list: icon/thumbnail + title + metadata.
struct ItemRowView: View {
    let item: ClipboardItem

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    Text(item.displayTitle)
                        .lineLimit(1)
                        .fontWeight(item.isPinned ? .semibold : .regular)
                        .textSelection(.enabled)
                }

                HStack(spacing: 6) {
                    Text(item.type.displayName)
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(Color.forContentType(item.type).opacity(0.18))
                        )
                        .foregroundStyle(Color.forContentType(item.type))

                    if let domain = item.urlDomain, !domain.isEmpty {
                        Text(domain).lineLimit(1).textSelection(.enabled)
                    }
                    if let app = item.sourceApp, !app.isEmpty {
                        Text("· \(app)").lineLimit(1).textSelection(.enabled)
                    }
                    Spacer(minLength: 0)
                    Text(item.capturedAt.relativeDescription)
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if item.type == .image, let data = item.imageData, let image = ImageHelper.image(from: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        } else {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.forContentType(item.type).opacity(0.15))
                .overlay(
                    Image(systemName: item.type.systemImage)
                        .foregroundStyle(Color.forContentType(item.type))
                )
        }
    }
}
