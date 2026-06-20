import AppKit
import QuartzCore

@MainActor
final class SwitcherPanelController {
    private let panel: NSPanel
    private let contentView: SwitcherPanelView

    init() {
        contentView = SwitcherPanelView()
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = contentView
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.setAccessibilityElement(false)
        contentView.setAccessibilityElement(false)
    }

    func show(on screen: NSScreen?, windows: [WindowEntry], selectedIndex: Int) {
        contentView.update(windows: windows, selectedIndex: selectedIndex)
        let size = panelSize(for: windows.count)
        let panelFrame = centeredFrame(size: size, on: screen)
        panel.setFrame(panelFrame, display: true)
        guard !panel.isVisible else {
            panel.orderFrontRegardless()
            return
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func updateSelection(to index: Int) {
        contentView.updateSelection(to: index)
    }

    func hide() {
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
            self?.panel.alphaValue = 1
        }
    }

    private func panelSize(for itemCount: Int) -> CGSize {
        let clamped = max(2, min(itemCount, 5))
        let width = min(980, CGFloat(clamped) * 208 + 72)
        return CGSize(width: width, height: 232)
    }

    private func centeredFrame(size: CGSize, on screen: NSScreen?) -> CGRect {
        let screenFrame = (screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let origin = CGPoint(x: screenFrame.midX - size.width / 2, y: screenFrame.midY - size.height / 2)
        return CGRect(origin: origin, size: size)
    }
}
