import AppKit
import CoreGraphics

final class WindowCatalog {
    private enum MatchRigour {
        case list
        case activation
    }

    private let bridge: AccessibilityBridge
    private let excludedOwners: Set<String> = [
        "Window Server", "Dock", "Control Center", "Notification Center", "SystemUIServer"
    ]

    init(bridge: AccessibilityBridge) {
        self.bridge = bridge
    }

    @MainActor
    func fetchVisibleWindows(excluding ownPID: pid_t) -> [WindowEntry] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let cgWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        var entries: [WindowEntry] = []
        var axCache: [pid_t: [AccessibilityBridge.AXWindowSnapshot]] = [:]
        var seen = Set<String>()
        for (index, info) in cgWindows.enumerated() {
            guard let entry = makeEntry(from: info, zIndex: index, excluding: ownPID, axCache: &axCache) else {
                continue
            }
            guard seen.insert(entry.id).inserted else { continue }
            entries.append(entry)
        }
        return entries
    }

    @MainActor
    func activate(_ entry: WindowEntry) async -> Bool {
        guard let refreshedTarget = refreshedAXWindow(for: entry) else { return false }
        let result = await bridge.activate(
            window: refreshedTarget.element,
            pid: entry.pid,
            application: entry.runningApplication,
            expectedIdentity: entry.identity,
            expectedWindow: refreshedTarget.element
        )
        return result == .success
    }

    private func makeEntry(
        from info: [String: Any],
        zIndex: Int,
        excluding ownPID: pid_t,
        axCache: inout [pid_t: [AccessibilityBridge.AXWindowSnapshot]]
    ) -> WindowEntry? {
        guard let pidNumber = info[kCGWindowOwnerPID as String] as? NSNumber else { return nil }
        let pid = pidNumber.int32Value
        guard pid != ownPID else { return nil }
        let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
        guard layer == 0 else { return nil }
        let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
        guard alpha > 0.01 else { return nil }
        let ownerName = (info[kCGWindowOwnerName as String] as? String) ?? ""
        guard !excludedOwners.contains(ownerName) else { return nil }
        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        guard app.activationPolicy == .regular else { return nil }
        guard
            let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
            bounds.width >= 80,
            bounds.height >= 60
        else {
            return nil
        }
        let windowID = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0
        let rawTitle = (info[kCGWindowName as String] as? String) ?? ""
        let appName = sanitizeWindowTitle(app.localizedName ?? ownerName)
        var axWindows = axCache[pid] ?? bridge.windows(for: pid)
        guard let matchedAXWindow = bestMatch(
            forTitle: rawTitle, bounds: bounds, among: axWindows, rigour: .list
        ) else {
            return nil
        }
        consume(snapshot: matchedAXWindow, from: &axWindows)
        axCache[pid] = axWindows
        let resolvedTitle = sanitizeWindowTitle(
            rawTitle.isEmpty && !matchedAXWindow.title.isEmpty ? matchedAXWindow.title : rawTitle
        )
        return WindowEntry(
            id: "\(pid)-\(windowID)",
            windowID: windowID,
            pid: pid,
            appName: appName,
            title: resolvedTitle,
            frame: bounds,
            zIndex: zIndex,
            runningApplication: app,
            axWindow: matchedAXWindow.element
        )
    }

    private func bestMatch(
        forTitle title: String,
        bounds: CGRect,
        among snapshots: [AccessibilityBridge.AXWindowSnapshot],
        rigour: MatchRigour
    ) -> AccessibilityBridge.AXWindowSnapshot? {
        guard !snapshots.isEmpty else { return nil }
        let normalizedTitle = normalize(title)
        let maximumAcceptedScore: CGFloat = normalizedTitle.isEmpty ? 160 : 80
        let ambiguityMargin: CGFloat = normalizedTitle.isEmpty ? 18 : 10
        let rankedCandidates = snapshots
            .map { snapshot in (snapshot: snapshot, score: score(for: snapshot, normalizedTitle: normalizedTitle, bounds: bounds)) }
            .sorted { $0.score < $1.score }
        guard let bestCandidate = rankedCandidates.first else { return nil }
        guard bestCandidate.score <= maximumAcceptedScore else { return nil }
        if rigour == .activation,
           let secondCandidate = rankedCandidates.dropFirst().first,
           abs(secondCandidate.score - bestCandidate.score) <= ambiguityMargin {
            let bestSig = FrameSignature(bestCandidate.snapshot.frame)
            let secondSig = FrameSignature(secondCandidate.snapshot.frame)
            if bestSig == secondSig { return nil }
        }
        return bestCandidate.snapshot
    }

    private func score(
        for snapshot: AccessibilityBridge.AXWindowSnapshot,
        normalizedTitle: String,
        bounds: CGRect
    ) -> CGFloat {
        let normalizedCandidate = normalize(snapshot.title)
        let frameDelta =
            abs(snapshot.frame.origin.x - bounds.origin.x) +
            abs(snapshot.frame.origin.y - bounds.origin.y) +
            abs(snapshot.frame.width - bounds.width) +
            abs(snapshot.frame.height - bounds.height)
        if normalizedTitle.isEmpty || normalizedCandidate.isEmpty { return frameDelta + 40 }
        if normalizedCandidate == normalizedTitle { return frameDelta }
        return frameDelta + 5_000
    }

    private func normalize(_ title: String) -> String {
        sanitizeWindowTitle(title).lowercased()
    }

    private func refreshedAXWindow(for entry: WindowEntry) -> AccessibilityBridge.AXWindowSnapshot? {
        let snapshots = bridge.windows(for: entry.pid)
        if let exactMatch = snapshots.first(where: { CFEqual($0.element, entry.axWindow) }) {
            return exactMatch
        }
        if let strictMatch = bestMatch(forTitle: entry.title, bounds: entry.frame, among: snapshots, rigour: .activation) {
            return strictMatch
        }
        if let listMatch = bestMatch(forTitle: entry.title, bounds: entry.frame, among: snapshots, rigour: .list) {
            return listMatch
        }
        return AccessibilityBridge.AXWindowSnapshot(element: entry.axWindow, title: entry.title, frame: entry.frame)
    }

    private func consume(
        snapshot: AccessibilityBridge.AXWindowSnapshot,
        from snapshots: inout [AccessibilityBridge.AXWindowSnapshot]
    ) {
        if let index = snapshots.firstIndex(where: { CFEqual($0.element, snapshot.element) }) {
            snapshots.remove(at: index)
        }
    }
}
