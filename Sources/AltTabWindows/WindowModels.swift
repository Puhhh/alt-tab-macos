import AppKit
import ApplicationServices

struct FrameSignature: Hashable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    init(_ frame: CGRect) {
        x = Int((frame.origin.x / 4).rounded())
        y = Int((frame.origin.y / 4).rounded())
        width = Int((frame.width / 4).rounded())
        height = Int((frame.height / 4).rounded())
    }
}

struct WindowIdentity: Hashable {
    let pid: pid_t
    let windowID: CGWindowID?
    let normalizedTitle: String
    let frameSignature: FrameSignature

    init(pid: pid_t, windowID: CGWindowID? = nil, title: String, frame: CGRect) {
        self.pid = pid
        self.windowID = windowID
        normalizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        frameSignature = FrameSignature(frame)
    }
}

struct FocusedWindowContext {
    let identity: WindowIdentity
    let frame: CGRect
    let window: AXUIElement
}

enum WindowActivationResult {
    case success
    case windowNotFound
    case activationFailed
}

struct WindowEntry: Identifiable {
    let id: String
    let windowID: CGWindowID
    let pid: pid_t
    let appName: String
    let title: String
    let frame: CGRect
    let zIndex: Int
    let runningApplication: NSRunningApplication
    let axWindow: AXUIElement

    var displayTitle: String {
        title.isEmpty ? "Untitled Window" : title
    }

    var icon: NSImage? {
        runningApplication.icon
    }

    var identity: WindowIdentity {
        let resolvedTitle = title.isEmpty ? appName : title
        return WindowIdentity(pid: pid, windowID: windowID, title: resolvedTitle, frame: frame)
    }
}
