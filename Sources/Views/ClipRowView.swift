import SwiftUI

/// Single row in the clip list — shows preview, type badge, source app, and timestamp.
struct ClipRowView: View {
    let clip: ClipItem
    let isSelected: Bool
    var onCopy: () -> Void
    var onDelete: () -> Void
    var onTogglePin: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Content type indicator
            typeIndicator

            // Main content area
            VStack(alignment: .leading, spacing: 3) {
                // Preview text
                Text(clip.content.truncatedLines(2))
                    .font(.system(size: 12.5, weight: .regular, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // AI Summary (if available)
                if let summary = clip.summary {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8))
                            .foregroundStyle(Color(hex: "#A371F7"))
                        Text(summary)
                            .font(.system(size: 10.5, weight: .regular, design: .default))
                            .foregroundStyle(Color(hex: "#A371F7").opacity(0.8))
                            .lineLimit(1)
                    }
                }

                // Metadata row
                HStack(spacing: 6) {
                    // Source app icon + name
                    if let appName = clip.sourceApp {
                        HStack(spacing: 3) {
                            if let icon = AppIconHelper.icon(for: clip.sourceAppBundleID) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 12, height: 12)
                            }
                            Text(appName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Content type badge
                    Text(clip.type.label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(hex: clip.type.accentHex))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background {
                            Capsule()
                                .fill(Color(hex: clip.type.accentHex).opacity(0.15))
                        }

                    // AI tags
                    if let tags = clip.aiTags?.components(separatedBy: ",").prefix(2),
                       !tags.isEmpty {
                        ForEach(Array(tags), id: \.self) { tag in
                            Text(tag.trimmingCharacters(in: .whitespaces))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Color(hex: "#3FB950"))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background {
                                    Capsule()
                                        .fill(Color(hex: "#3FB950").opacity(0.12))
                                }
                        }
                    }

                    Spacer()

                    // Timestamp
                    Text(clip.timestamp.relativeString)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    // Pin indicator
                    if clip.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: "#F0883E"))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? Color.accentColor.opacity(0.4)
                        : Color.clear,
                    lineWidth: 1
                )
        }
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onCopy()
        }
        .contextMenu {
            Button {
                onCopy()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button {
                onTogglePin()
            } label: {
                Label(
                    clip.isPinned ? "Unpin" : "Pin",
                    systemImage: clip.isPinned ? "pin.slash" : "pin"
                )
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Subviews

    private var typeIndicator: some View {
        Image(systemName: clip.type.iconName)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color(hex: clip.type.accentHex))
            .frame(width: 28, height: 28)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(hex: clip.type.accentHex).opacity(0.12))
            }
    }

    private var backgroundColor: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.08))
        } else if isHovered {
            return AnyShapeStyle(Color.white.opacity(0.04))
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }
}
