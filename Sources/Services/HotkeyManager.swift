import AppKit
import Carbon.HIToolbox

/// Manages the global ⌥V keyboard shortcut to toggle the popover.
final class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// Callback when the hotkey is pressed.
    var onHotkey: (() -> Void)?

    init() {}

    // MARK: - Lifecycle

    /// Start listening for ⌥V globally and locally.
    func start() {
        // Global monitor: fires when another app is frontmost
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local monitor: fires when our app is frontmost
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil  // consume the event
            }
            return event
        }
    }

    /// Stop listening.
    func stop() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    // MARK: - Event Handling

    /// Check if the event is ⌥V and fire the callback.
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Check for Option (⌥) modifier and 'V' key
        guard event.modifierFlags.contains(.option),
              event.keyCode == UInt16(kVK_ANSI_V) else {
            return false
        }

        // Make sure no other modifiers are pressed (just ⌥)
        let cleanFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard cleanFlags == .option else {
            return false
        }

        DispatchQueue.main.async { [weak self] in
            self?.onHotkey?()
        }
        return true
    }

    deinit {
        stop()
    }
}
