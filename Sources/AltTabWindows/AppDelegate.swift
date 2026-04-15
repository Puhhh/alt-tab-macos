import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var controller: AppController?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }
}
