import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    weak var controller: AppController?
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private weak var mainWindow: NSWindow?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }

    func captureMainWindow(_ window: NSWindow?) {
        guard let window else { return }
        mainWindow = window
        window.delegate = self
        window.isReleasedWhenClosed = false
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hideMainWindow()
        return false
    }

    @objc func showMainWindow(_ sender: Any?) {
        guard let window = resolvedMainWindow() else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(sender)
    }

    @objc func quitApplication(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    private func hideMainWindow() {
        resolvedMainWindow()?.orderOut(nil)
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "macwindow.badge.plus", accessibilityDescription: "AltTab")
            button.imagePosition = .imageOnly
            button.toolTip = "AltTab"
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Open AltTab", action: #selector(showMainWindow(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit AltTab", action: #selector(quitApplication(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func resolvedMainWindow() -> NSWindow? {
        if let mainWindow {
            return mainWindow
        }

        let window = NSApp.windows.first { !($0 is NSPanel) }
        mainWindow = window
        mainWindow?.delegate = self
        return window
    }
}
