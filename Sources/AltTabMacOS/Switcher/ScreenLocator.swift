import AppKit
import CoreGraphics

enum ScreenLocator {
    static func screen(containing frame: CGRect) -> NSScreen? {
        guard !frame.isNull, !frame.isEmpty else { return nil }
        var displayIDs = Array(repeating: CGDirectDisplayID(), count: 16)
        var displayCount: UInt32 = 0
        let status = CGGetDisplaysWithRect(frame, UInt32(displayIDs.count), &displayIDs, &displayCount)
        let candidateIDs: [CGDirectDisplayID]
        if status == .success {
            candidateIDs = Array(displayIDs.prefix(Int(displayCount)))
        } else {
            candidateIDs = NSScreen.screens.compactMap(displayID(for:))
        }
        let bestDisplay = candidateIDs.max { lhs, rhs in
            intersectionArea(frame, CGDisplayBounds(lhs)) < intersectionArea(frame, CGDisplayBounds(rhs))
        }
        guard let bestDisplay else { return NSScreen.main }
        return screen(for: bestDisplay) ?? NSScreen.main
    }

    private static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return screenNumber.uint32Value == displayID
        }
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(screenNumber.uint32Value)
    }

    private static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        return intersection.width * intersection.height
    }
}
