import SwiftUI

/// Scrollable list of recent clipboard items with keyboard navigation.
struct ClipListView: View {
    @ObservedObject var viewModel: ClipListViewModel
    var onDismiss: (() -> Void)?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 2) {
                    ForEach(viewModel.clips) { clip in
                        ClipRowView(
                            clip: clip,
                            isSelected: viewModel.selectedClipID == clip.id,
                            onCopy: {
                                viewModel.copyToClipboard(clip)
                                withAnimation(.easeOut(duration: 0.15)) {
                                    onDismiss?()
                                }
                            },
                            onDelete: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    viewModel.deleteClip(clip)
                                }
                            },
                            onTogglePin: {
                                viewModel.togglePin(clip)
                            }
                        )
                        .id(clip.id)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .onChange(of: viewModel.selectedClipID) { _, newID in
                if let id = newID {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }
}
