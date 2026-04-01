import AppKit
import SwiftUI

/// Manages the NSStatusItem (menu bar icon) and NSPopover.
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var clipboardWatcher: ClipboardWatcher!
    private var hotkeyManager: HotkeyManager!
    private var eventMonitor: Any?

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupClipboardWatcher()
        setupHotkeyManager()
        BackgroundProcessor.shared.start()
        setupClickOutsideMonitor()

        // Hide dock icon (belt-and-suspenders with LSUIElement)
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardWatcher.stop()
        hotkeyManager.stop()
        BackgroundProcessor.shared.stop()
    }

    // MARK: - Status Item (Menu Bar Icon)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = logoImage(accessibilityDescription: "ClipStash")

            button.action = #selector(togglePopover)
            button.target = self

            // Subtle animation on new clip
            button.appearsDisabled = false
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.behavior = .transient  // auto-close when clicking outside
        popover.animates = true

        let contentView = PopoverContentView(onDismiss: { [weak self] in
            self?.closePopover()
        })
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    @objc func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Bring app to front so the popover can receive keyboard events
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    // MARK: - Clipboard Watcher

    private func setupClipboardWatcher() {
        clipboardWatcher = ClipboardWatcher()
        clipboardWatcher.onNewClip = { [weak self] clip in
            // Flash the menu bar icon briefly on new clip
            self?.flashStatusIcon()
            // Trigger background AI processing for the new clip
            BackgroundProcessor.shared.processImmediately(clip)
        }
        clipboardWatcher.start()
    }

    /// Brief visual feedback when a new clip is captured.
    private func flashStatusIcon() {
        guard let button = statusItem.button else { return }

        let originalImage = button.image
        button.alphaValue = 0.72

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            button.image = originalImage
            button.alphaValue = 1.0
        }
    }

    private func logoImage(accessibilityDescription: String) -> NSImage? {
        let image = NSImage(named: "AppLogo")
        image?.size = NSSize(width: 18, height: 18)
        image?.accessibilityDescription = accessibilityDescription
        image?.isTemplate = false
        return image
    }

    // MARK: - Hotkey

    private func setupHotkeyManager() {
        hotkeyManager = HotkeyManager()
        hotkeyManager.onHotkey = { [weak self] in
            self?.togglePopover()
        }
        hotkeyManager.start()
    }

    // MARK: - Click Outside Monitor

    /// Close popover when user clicks outside (backup for .transient).
    private func setupClickOutsideMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self = self, self.popover.isShown else { return }
            self.closePopover()
        }
    }
}
