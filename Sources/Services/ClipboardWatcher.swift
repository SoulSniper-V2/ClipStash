import AppKit
import CryptoKit
import Foundation

/// Monitors the system clipboard for changes and stores new clips.
final class ClipboardWatcher {
    private var timer: Timer?
    private var lastChangeCount: Int
    private let repository: ClipRepository
    private let pollInterval: TimeInterval

    /// Callback fired when a new clip is captured (for UI refresh hints).
    var onNewClip: ((ClipItem) -> Void)?

    /// Bundle IDs that should never be captured (password managers, banking, etc.).
    /// Users can extend this list via settings in a future version.
    private var blocklist: Set<String> = [
        // 1Password
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-osx",
        // LastPass
        "com.lastpass.LastPass",
        "com.lastpass.lastpass",
        // Bitwarden
        "com.bitwarden.desktop",
        // Dashlane
        "com.dashlane.Dashlane",
        // macOS Keychain
        "com.apple.keychainaccess",
        // KeePassXC
        "org.keepassxc.keepassxc",
        // Enpass
        "in.sinew.Enpass-Desktop",
    ]

    init(
        repository: ClipRepository = ClipRepository(),
        pollInterval: TimeInterval = 0.5
    ) {
        self.repository = repository
        self.pollInterval = pollInterval
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    // MARK: - Blocklist Management

    /// Add a bundle ID to the blocklist.
    func blockApp(bundleID: String) {
        blocklist.insert(bundleID)
    }

    /// Remove a bundle ID from the blocklist.
    func unblockApp(bundleID: String) {
        blocklist.remove(bundleID)
    }

    /// Check if a bundle ID is blocked.
    func isBlocked(bundleID: String) -> Bool {
        blocklist.contains(bundleID)
    }

    // MARK: - Lifecycle

    /// Start watching the clipboard.
    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(
            withTimeInterval: pollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkClipboard()
        }
        // Ensure timer fires even during UI tracking (scrolling, etc.)
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Stop watching the clipboard.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Polling

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // Check if the source app is on the blocklist
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleID = frontApp.bundleIdentifier,
           blocklist.contains(bundleID) {
            return  // silently skip — never capture from blocked apps
        }

        // Try to read string content
        guard let content = pasteboard.string(forType: .string),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Don't capture if it's very short whitespace
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 1 else { return }

        // Detect content type
        let contentType = ContentType.detect(from: content)

        // Compute hash for deduplication
        let hash = sha256(content)

        // Get the frontmost application info
        let sourceApp = NSWorkspace.shared.frontmostApplication
        let appName = sourceApp?.localizedName
        let bundleID = sourceApp?.bundleIdentifier

        // Build the clip item
        let clip = ClipItem(
            id: nil,
            content: content,
            contentType: contentType.rawValue,
            sourceApp: appName,
            sourceAppBundleID: bundleID,
            timestamp: Date(),
            isPinned: false,
            contentHash: hash,
            summary: nil,
            aiTags: nil,
            embedding: nil
        )

        // Insert into database
        do {
            let saved = try repository.insert(clip)
            onNewClip?(saved)
        } catch {
            print("ClipboardWatcher: Failed to save clip: \(error)")
        }
    }

    // MARK: - Hashing

    private func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
