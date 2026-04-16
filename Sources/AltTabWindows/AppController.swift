import AppKit
import SwiftUI

@MainActor
final class AppController: ObservableObject {
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var switcherVisible = false
    @Published private(set) var hotKeyErrorMessage: String?
    @Published var visibleWindows: [WindowEntry] = []
    @Published var selectedIndex = 0

    private let bridge = AccessibilityBridge()
    private lazy var catalog = WindowCatalog(bridge: bridge)
    private let history = WindowHistory()
    private let hotKeys = HotKeyCenter()
    private lazy var panelController = SwitcherPanelController(
        rootView: AnyView(SwitcherPanelView().environmentObject(self))
    )
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
        hotKeys.onTrigger = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleHotKey()
            }
        }
        hotKeys.onRegistrationFailure = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.hotKeyErrorMessage = message
            }
        }
        hotKeys.onModifierRelease = { [weak self] in
            Task { @MainActor [weak self] in
                self?.activateSelectionIfNeeded()
            }
        }
        hotKeys.onEscape = { [weak self] in
            Task { @MainActor [weak self] in
                self?.cancelSwitcher()
            }
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
        accessibilityGranted = AccessibilityPermissionCenter.isTrusted()
    }

    func requestAccessibilityAccess() {
        accessibilityGranted = AccessibilityPermissionCenter.requestAccessPrompt()
        if !accessibilityGranted {
            AccessibilityPermissionCenter.openSystemSettings()
        }
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
            let fallbackFrame = orderedWindows[selectedIndex].frame
            switcherScreen = screenForSwitcher(currentFrame: currentContext?.frame, fallbackFrame: fallbackFrame)
            hotKeys.beginSwitcherSession()
        }

        panelController.show(on: switcherScreen, itemCount: visibleWindows.count)
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
        guard !visibleWindows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % visibleWindows.count
    }

    private func initialSelectionIndex(
        in windows: [WindowEntry],
        current: WindowIdentity?
    ) -> Int {
        guard !windows.isEmpty else { return 0 }
        guard windows.count > 1 else { return 0 }

        if let current, let currentIndex = windows.firstIndex(where: { $0.identity == current }) {
            return (currentIndex + 1) % windows.count
        }

        return 0
    }

    private func screenForSwitcher(currentFrame: CGRect?, fallbackFrame: CGRect) -> NSScreen? {
        if let currentFrame, let activeScreen = screen(containing: currentFrame) {
            return activeScreen
        }

        return screen(containing: fallbackFrame) ?? NSScreen.main
    }

    private func screen(containing frame: CGRect) -> NSScreen? {
        guard !frame.isNull, !frame.isEmpty else { return nil }

        let rankedScreens = NSScreen.screens
            .map { screen in
                (screen: screen, overlap: screen.frame.intersection(frame).area)
            }
            .sorted { lhs, rhs in
                lhs.overlap > rhs.overlap
            }

        if let bestMatch = rankedScreens.first, bestMatch.overlap > 0 {
            return bestMatch.screen
        }

        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.main
    }

    private func resolvedCurrentIdentity(
        from context: FocusedWindowContext?,
        in windows: [WindowEntry]
    ) -> WindowIdentity? {
        guard let context else { return nil }
        if let exactMatch = windows.first(where: { CFEqual($0.axWindow, context.window) }) {
            return exactMatch.identity
        }
        return context.identity
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }
}
