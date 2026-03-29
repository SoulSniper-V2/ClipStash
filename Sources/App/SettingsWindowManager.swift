import AppKit
import SwiftUI

/// Manages a standalone AppKit window for the application Settings.
/// This bypasses SwiftUI's native `Settings {}` scene which often drops
/// its responder (`showSettingsWindow:`) in `.accessory` (menu-bar only) apps.
final class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    
    private var window: NSWindow?
    
    private init() {}
    
    func show() {
        if window == nil {
            let hostingController = NSHostingController(rootView: SettingsView())
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            newWindow.center()
            newWindow.setFrameAutosaveName("ClipStash Settings")
            newWindow.isReleasedWhenClosed = false // Keep the window instance alive when closed
            newWindow.contentViewController = hostingController
            newWindow.title = "Preferences"
            self.window = newWindow
        }
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
