import AppKit
import Foundation

extension NSRunningApplication {
    /// Get the app's display name, falling back to bundle ID.
    var displayName: String {
        localizedName ?? bundleIdentifier ?? "Unknown"
    }
}

/// Helper to get an app icon from a bundle identifier.
enum AppIconHelper {
    /// Returns the app icon for a given bundle identifier.
    static func icon(for bundleID: String?) -> NSImage? {
        guard let bundleID = bundleID,
              let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleID
              ) else {
            return NSImage(systemSymbolName: "app", accessibilityDescription: "App")
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 20, height: 20)
        return icon
    }

    /// Returns the app icon as a SwiftUI-compatible Image.
    static func iconImage(for bundleID: String?) -> NSImage {
        return icon(for: bundleID)
            ?? NSImage(systemSymbolName: "app", accessibilityDescription: "App")
            ?? NSImage()
    }
}
