import AppKit
import QuartzCore

@MainActor
final class SwitcherPanelView: NSView {
    private let visualEffect = NSVisualEffectView()
    private let scrollView = NSScrollView()
    private let documentView = NSView()
    private var cardViews: [SwitcherCardView] = []
    private var selectedIndex = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) { nil }

    func update(windows: [WindowEntry], selectedIndex: Int) {
        self.selectedIndex = selectedIndex
        cardViews.forEach { $0.removeFromSuperview() }
        cardViews.removeAll()
        let cardW: CGFloat = 210
        let cardH: CGFloat = 132
        let gap: CGFloat = 12
        let pad: CGFloat = 16
        var x = pad
        for (i, entry) in windows.enumerated() {
            let card = SwitcherCardView(
                frame: NSRect(x: x, y: pad, width: cardW, height: cardH),
                entry: entry,
                selected: i == selectedIndex
            )
            documentView.addSubview(card)
            cardViews.append(card)
            x += cardW + gap
        }
        let panelWidth = bounds.width > 0 ? bounds.width : (x - gap + pad)
        let docWidth = max(x - gap + pad, panelWidth)
        let docHeight = bounds.height > 0 ? bounds.height : (cardH + 2 * pad)
        documentView.frame = NSRect(x: 0, y: 0, width: docWidth, height: docHeight)
        scrollToSelected()
    }

    func updateSelection(to index: Int) {
        if cardViews.indices.contains(selectedIndex) { cardViews[selectedIndex].setSelected(false) }
        selectedIndex = index
        if cardViews.indices.contains(index) { cardViews[index].setSelected(true) }
        scrollToSelected()
    }

    private func setupView() {
        wantsLayer = true
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 24
        visualEffect.layer?.masksToBounds = true
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        addSubview(visualEffect)
        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = documentView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func scrollToSelected() {
        guard cardViews.indices.contains(selectedIndex) else { return }
        let card = cardViews[selectedIndex]
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            scrollView.contentView.animator().scrollToVisible(card.frame)
        }
    }
}

@MainActor
private final class SwitcherCardView: NSView {
    private let hintLabel: NSTextField
    private var isSelected: Bool

    init(frame: NSRect, entry: WindowEntry, selected: Bool) {
        hintLabel = NSTextField(labelWithString: "")
        isSelected = selected
        super.init(frame: frame)
        setupView(entry: entry)
        applySelection(animated: false)
    }

    required init?(coder: NSCoder) { nil }

    func setSelected(_ selected: Bool) {
        isSelected = selected
        applySelection(animated: true)
    }

    private func setupView(entry: WindowEntry) {
        wantsLayer = true
        layer?.cornerRadius = 18
        let iconView = NSImageView()
        iconView.image = entry.icon ?? NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.frame = NSRect(x: 3, y: 3, width: 24, height: 24)
        let iconContainer = NSView(frame: NSRect(x: 0, y: 0, width: 30, height: 30))
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 9
        iconContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        iconContainer.addSubview(iconView)
        let titleLabel = NSTextField(labelWithString: entry.displayTitle)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.truncatesLastVisibleLine = true
        let appLabel = NSTextField(labelWithString: entry.appName)
        appLabel.font = .systemFont(ofSize: 11, weight: .medium)
        appLabel.textColor = .secondaryLabelColor
        appLabel.lineBreakMode = .byTruncatingTail
        let sizeLabel = NSTextField(labelWithString: "\(Int(entry.frame.width)) × \(Int(entry.frame.height))")
        sizeLabel.font = .systemFont(ofSize: 11, weight: .medium)
        hintLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        hintLabel.textColor = .secondaryLabelColor
        let pad: CGFloat = 16
        let innerW = frame.width - 2 * pad
        iconContainer.frame = NSRect(x: pad, y: frame.height - pad - 30, width: 30, height: 30)
        titleLabel.frame = NSRect(x: pad + 42, y: frame.height - pad - 22, width: innerW - 42, height: 18)
        appLabel.frame = NSRect(x: pad + 42, y: frame.height - pad - 42, width: innerW - 42, height: 16)
        let bottomY: CGFloat = pad
        hintLabel.frame = NSRect(x: pad, y: bottomY + 18, width: innerW, height: 14)
        sizeLabel.frame = NSRect(x: pad, y: bottomY, width: innerW, height: 16)
        addSubview(iconContainer)
        addSubview(titleLabel)
        addSubview(appLabel)
        addSubview(hintLabel)
        addSubview(sizeLabel)
    }

    private func applySelection(animated: Bool) {
        hintLabel.stringValue = isSelected ? "Release Option to switch" : "Visible window"
        let bg = isSelected
            ? NSColor.controlBackgroundColor.withAlphaComponent(0.94).cgColor
            : NSColor.black.withAlphaComponent(0.16).cgColor
        let border = isSelected
            ? NSColor.controlAccentColor.cgColor
            : NSColor.white.withAlphaComponent(0.06).cgColor
        let scale: CGFloat = isSelected ? 1.03 : 1.0
        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? 0.14 : 0)
        layer?.backgroundColor = bg
        layer?.borderColor = border
        layer?.borderWidth = isSelected ? 2 : 1
        layer?.transform = CATransform3DMakeScale(scale, scale, 1)
        CATransaction.commit()
    }
}
