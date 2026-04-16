import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = AppController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }

    @objc func showSettings(_ sender: Any?) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(controller: controller)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(sender)
    }

    @objc func quit(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "macwindow.badge.plus", accessibilityDescription: "AltTab")
            button.imagePosition = .imageOnly
            button.toolTip = "AltTab"
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Open AltTab", action: #selector(showSettings(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit AltTab", action: #selector(quit(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }
}
