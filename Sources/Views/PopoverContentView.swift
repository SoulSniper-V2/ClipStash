import SwiftUI

/// Main popover container — header, search, clip list, footer.
struct PopoverContentView: View {
    @StateObject private var viewModel = ClipListViewModel()
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerBar

            Divider()
                .opacity(0.3)

            // MARK: - Search
            HStack(spacing: 6) {
                SearchBarView(text: $viewModel.searchQuery)

                // AI search toggle (only visible if llm is installed)
                if viewModel.aiAvailable {
                    Button {
                        viewModel.toggleSearchMode()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: viewModel.searchMode == .semantic
                                ? "sparkles" : "text.magnifyingglass")
                                .font(.system(size: 10))
                            Text(viewModel.searchMode.rawValue)
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(
                            viewModel.searchMode == .semantic
                                ? Color(hex: "#A371F7")
                                : .secondary
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    viewModel.searchMode == .semantic
                                        ? Color(hex: "#A371F7").opacity(0.15)
                                        : Color.white.opacity(0.06)
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Semantic search indicator
            if viewModel.isSemanticSearching {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text("Searching with AI…")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#A371F7"))
                }
                .padding(.bottom, 4)
                .transition(.opacity)
            }

            // MARK: - Content
            if viewModel.clips.isEmpty {
                EmptyStateView(isSearching: viewModel.isSearching)
                    .frame(maxHeight: .infinity)
            } else {
                ClipListView(viewModel: viewModel, onDismiss: onDismiss)
                    .frame(maxHeight: .infinity)
            }

            Divider()
                .opacity(0.3)

            // MARK: - Footer
            footerBar
        }
        .frame(width: 380, height: 520)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    LinearGradient(
                        colors: [
                            Color(hex: "#0D1117").opacity(0.6),
                            Color(hex: "#161B22").opacity(0.4),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .onKeyPress(.upArrow) {
            viewModel.moveSelection(direction: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.moveSelection(direction: 1)
            return .handled
        }
        .onKeyPress(.return) {
            if viewModel.copySelectedAndDismiss() {
                onDismiss?()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            onDismiss?()
            return .handled
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            // App branding
            HStack(spacing: 6) {
                Image(systemName: "clipboard.fill")
                    .font(.system(size: 14, weight: .semibold))
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

                Text("ClipStash")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Keyboard shortcut hint
            Text("⌥V")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                        }
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Text("\(viewModel.totalCount) clips")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()

            if !viewModel.clips.isEmpty {
                Button {
                    viewModel.clearAll()
                } label: {
                    Text("Clear All")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "#F85149"))
                }
                .buttonStyle(.plain)
                .opacity(0.8)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
