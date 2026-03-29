import SwiftUI

/// Empty state shown when there are no clips or no search results.
struct EmptyStateView: View {
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: isSearching ? "magnifyingglass" : "clipboard")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "#58A6FF"),
                            Color(hex: "#A371F7"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: 6) {
                Text(isSearching ? "No results" : "No clips yet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(isSearching
                    ? "Try a different search term"
                    : "Copy something to get started")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
