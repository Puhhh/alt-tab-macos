import AppKit
import ApplicationServices

final class AccessibilityBridge {
    struct AXWindowSnapshot {
        let element: AXUIElement
        let title: String
        let frame: CGRect
    }

    func windows(for pid: pid_t) -> [AXWindowSnapshot] {
        guard AccessibilityPermissionCenter.isTrusted() else { return [] }
        let appElement = AXUIElementCreateApplication(pid)
        guard let windowElements: [AXUIElement] = copyAttribute(kAXWindowsAttribute as CFString, from: appElement) else {
            return []
        }
        return windowElements.compactMap { window in
            guard role(of: window) == (kAXWindowRole as String) else { return nil }
            guard boolAttribute(kAXMinimizedAttribute as CFString, from: window) != true else { return nil }
            guard let frame = frame(of: window), frame.width >= 80, frame.height >= 60 else { return nil }
            let title = stringAttribute(kAXTitleAttribute as CFString, from: window) ?? ""
            return AXWindowSnapshot(element: window, title: title, frame: frame)
        }
    }

    func currentFocusedWindowContext() -> FocusedWindowContext? {
        guard AccessibilityPermissionCenter.isTrusted() else { return nil }
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let focusedWindow: AXUIElement = copyAttribute(kAXFocusedWindowAttribute as CFString, from: appElement) else {
            return nil
        }
        guard let frame = frame(of: focusedWindow) else { return nil }
        let rawTitle = stringAttribute(kAXTitleAttribute as CFString, from: focusedWindow) ?? ""
        let title = sanitizeWindowTitle(rawTitle.isEmpty ? (app.localizedName ?? "Untitled Window") : rawTitle)
        return FocusedWindowContext(
            identity: WindowIdentity(pid: app.processIdentifier, title: title, frame: frame),
            frame: frame,
            window: focusedWindow
        )
    }

    @MainActor
    func activate(
        window: AXUIElement,
        pid: pid_t,
        application: NSRunningApplication,
        expectedIdentity: WindowIdentity,
        expectedWindow: AXUIElement
    ) async -> WindowActivationResult {
        application.unhide()
        let appElement = AXUIElementCreateApplication(pid)
        _ = AXUIElementSetMessagingTimeout(appElement, 0.5)
        _ = AXUIElementSetMessagingTimeout(window, 0.5)
        let retryDelays: [UInt64] = [0, 20_000_000, 60_000_000, 120_000_000, 200_000_000]
        var sawInvalidWindow = false
        for delay in retryDelays {
            if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
            application.activate(options: [])
            let frontmostResult = AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            if boolAttribute(kAXMinimizedAttribute as CFString, from: window) == true {
                let unminimizeResult = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                if !isAcceptable(unminimizeResult) {
                    if isInvalidWindowError(unminimizeResult) { sawInvalidWindow = true; break }
                    continue
                }
            }
            let mainResult = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            let focusedResult = AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            let raiseResult = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            if activationMatchesExpectedWindow(pid: pid, expectedIdentity: expectedIdentity, expectedWindow: expectedWindow) {
                return .success
            }
            let allAcceptable = isAcceptable(frontmostResult) && isAcceptable(mainResult) && isAcceptable(focusedResult) && isAcceptable(raiseResult)
            if !allAcceptable {
                if [frontmostResult, mainResult, focusedResult, raiseResult].contains(where: isInvalidWindowError) {
                    sawInvalidWindow = true
                    break
                }
                continue
            }
        }
        if activationMatchesExpectedWindow(pid: pid, expectedIdentity: expectedIdentity, expectedWindow: expectedWindow) {
            return .success
        }
        return sawInvalidWindow ? .windowNotFound : .activationFailed
    }

    private func role(of element: AXUIElement) -> String? {
        stringAttribute(kAXRoleAttribute as CFString, from: element)
    }

    private func stringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return nil }
        if let stringValue = value as? String { return stringValue }
        if let attributedString = value as? NSAttributedString { return attributedString.string }
        return nil
    }

    private func boolAttribute(_ attribute: CFString, from element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return nil }
        return (value as? NSNumber)?.boolValue
    }

    private func copyAttribute<T>(_ attribute: CFString, from element: AXUIElement) -> T? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return nil }
        return value as? T
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard
            let position = pointAttribute(kAXPositionAttribute as CFString, from: element),
            let size = sizeAttribute(kAXSizeAttribute as CFString, from: element)
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func pointAttribute(_ attribute: CFString, from element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else { return nil }
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        var point = CGPoint.zero
        return AXValueGetValue(axValue, .cgPoint, &point) ? point : nil
    }

    private func sizeAttribute(_ attribute: CFString, from element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else { return nil }
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        var size = CGSize.zero
        return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
    }

    private func activationMatchesExpectedWindow(
        pid: pid_t,
        expectedIdentity: WindowIdentity,
        expectedWindow: AXUIElement
    ) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return false }
        guard let currentContext = currentFocusedWindowContext() else { return false }
        if CFEqual(currentContext.window, expectedWindow) { return true }
        return currentContext.identity == expectedIdentity
    }

    private func isAcceptable(_ error: AXError) -> Bool {
        switch error {
        case .success, .attributeUnsupported, .actionUnsupported: return true
        default: return false
        }
    }

    private func isInvalidWindowError(_ error: AXError) -> Bool {
        switch error {
        case .invalidUIElement, .illegalArgument: return true
        default: return false
        }
    }
}
