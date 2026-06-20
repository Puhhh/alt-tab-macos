import AppKit

@MainActor
final class AppController {
    private(set) var accessibilityGranted = false
    private(set) var switcherVisible = false
    private(set) var hotKeyErrorMessage: String?
    private(set) var visibleWindows: [WindowEntry] = []
    private(set) var selectedIndex = 0

    var onUpdate: (() -> Void)?

    private let bridge = AccessibilityBridge()
    private lazy var catalog = WindowCatalog(bridge: bridge)
    private let history = WindowHistory()
    private let hotKeys = HotKeyCenter()
    private lazy var panelController = SwitcherPanelController()
    private var hasStarted = false
    private var switcherOriginIdentity: WindowIdentity?
    private var switcherScreen: NSScreen?

    var permissionStatusTitle: String {
        accessibilityGranted ? "Granted" : "Not granted"
    }

    var permissionStatusDescription: String {
        accessibilityGranted
            ? "AltTab can inspect and focus visible windows."
            : "Enable Accessibility access so the app can read window titles and focus the selected window."
    }

    var shortcutDescription: String {
        hotKeyErrorMessage ?? "Option + Tab switches to the next window."
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        refreshPermissionStatus()
        hotKeys.onTrigger = {
            Task { @MainActor [weak self] in self?.handleHotKey() }
        }
        hotKeys.onRegistrationFailure = { message in
            Task { @MainActor [weak self] in
                self?.hotKeyErrorMessage = message
                self?.onUpdate?()
            }
        }
        hotKeys.onModifierRelease = {
            Task { @MainActor [weak self] in self?.activateSelectionIfNeeded() }
        }
        hotKeys.onEscape = {
            Task { @MainActor [weak self] in self?.cancelSwitcher() }
        }
        hotKeys.start()
    }

    func stop() {
        hotKeys.stop()
        history.stop()
        switcherVisible = false
        switcherOriginIdentity = nil
        switcherScreen = nil
        panelController.hide()
    }

    func refreshPermissionStatus() {
        let previous = accessibilityGranted
        accessibilityGranted = AccessibilityPermissionCenter.isTrusted()
        if accessibilityGranted != previous { onUpdate?() }
    }

    func requestAccessibilityAccess() {
        accessibilityGranted = AccessibilityPermissionCenter.requestAccessPrompt()
        if !accessibilityGranted { AccessibilityPermissionCenter.openSystemSettings() }
        onUpdate?()
    }

    func openSystemSettings() {
        AccessibilityPermissionCenter.openSystemSettings()
    }

    func handleHotKey() {
        refreshPermissionStatus()
        guard accessibilityGranted else {
            requestAccessibilityAccess()
            NSSound.beep()
            return
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let currentContext = bridge.currentFocusedWindowContext()
        let rawWindows = catalog.fetchVisibleWindows(excluding: ownPID)
        let currentIdentity = resolvedCurrentIdentity(from: currentContext, in: rawWindows)
        let orderedWindows = history.order(entries: rawWindows, current: currentIdentity)
        guard !orderedWindows.isEmpty else {
            NSSound.beep()
            return
        }
        visibleWindows = orderedWindows
        if switcherVisible {
            moveSelection()
        } else {
            selectedIndex = initialSelectionIndex(in: orderedWindows, current: currentIdentity)
            switcherVisible = true
            switcherOriginIdentity = currentIdentity
            switcherScreen = ScreenLocator.screen(
                containing: currentContext?.frame ?? orderedWindows[selectedIndex].frame
            )
            hotKeys.beginSwitcherSession()
        }
        panelController.show(on: switcherScreen, windows: visibleWindows, selectedIndex: selectedIndex)
    }

    func activateSelectionIfNeeded() {
        guard switcherVisible, visibleWindows.indices.contains(selectedIndex) else { return }
        let selectedWindow = visibleWindows[selectedIndex]
        let previousIdentity = switcherOriginIdentity
        switcherVisible = false
        hotKeys.endSwitcherSession()
        panelController.hide()
        switcherOriginIdentity = nil
        switcherScreen = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            let activated = await self.catalog.activate(selectedWindow)
            if activated {
                self.history.noteActivation(from: previousIdentity, to: selectedWindow)
            } else {
                NSSound.beep()
            }
        }
    }

    func cancelSwitcher() {
        guard switcherVisible else { return }
        switcherVisible = false
        hotKeys.endSwitcherSession()
        switcherOriginIdentity = nil
        switcherScreen = nil
        panelController.hide()
    }

    private func moveSelection() {
        selectedIndex = (selectedIndex + 1) % visibleWindows.count
        panelController.updateSelection(to: selectedIndex)
    }

    private func initialSelectionIndex(in windows: [WindowEntry], current: WindowIdentity?) -> Int {
        guard windows.count > 1 else { return 0 }
        if let current, let idx = windows.firstIndex(where: { $0.identity == current }) {
            return (idx + 1) % windows.count
        }
        return 0
    }

    private func resolvedCurrentIdentity(
        from context: FocusedWindowContext?,
        in windows: [WindowEntry]
    ) -> WindowIdentity? {
        guard let context else { return nil }
        if let match = windows.first(where: { CFEqual($0.axWindow, context.window) }) {
            return match.identity
        }
        return context.identity
    }
}
