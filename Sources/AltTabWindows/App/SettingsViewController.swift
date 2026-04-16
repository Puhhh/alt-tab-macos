import AppKit

@MainActor
final class SettingsViewController: NSViewController {
    private weak var appController: AppController?
    private var permissionIconView: NSImageView!
    private var permissionDescLabel: NSTextField!
    private var permissionBadgeLabel: NSTextField!
    private var shortcutLabel: NSTextField!

    init(controller: AppController) {
        appController = controller
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 360))
        let outer = vstack([makeHeader(), makePermissionCard(), makeInstructionsCard(), makeFooter()], spacing: 18)
        outer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(outer)
        NSLayoutConstraint.activate([
            outer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            outer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            outer.topAnchor.constraint(equalTo: view.topAnchor, constant: 24)
        ])
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        appController?.refreshPermissionStatus()
        refresh()
    }

    func refresh() {
        guard let ctrl = appController else { return }
        let granted = ctrl.accessibilityGranted
        let color: NSColor = granted ? .systemGreen : .systemOrange
        permissionIconView.image = NSImage(
            systemSymbolName: granted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill",
            accessibilityDescription: granted ? "Accessibility permission granted" : "Accessibility permission not granted"
        )
        permissionIconView.contentTintColor = color
        permissionBadgeLabel.stringValue = ctrl.permissionStatusTitle
        permissionBadgeLabel.textColor = color
        permissionDescLabel.stringValue = ctrl.permissionStatusDescription
        shortcutLabel.stringValue = ctrl.shortcutDescription
        shortcutLabel.textColor = ctrl.hotKeyErrorMessage == nil ? .labelColor : .systemOrange
    }

    private func makeHeader() -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "macwindow.badge.plus", accessibilityDescription: "AltTab")
        icon.contentTintColor = .controlAccentColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 48),
            icon.heightAnchor.constraint(equalToConstant: 48)
        ])
        let title = label("AltTab", size: 24, weight: .semibold)
        let subtitle = label("Window switcher for macOS with real window focus", size: 13)
        subtitle.textColor = .secondaryLabelColor
        let textStack = vstack([title, subtitle], spacing: 4)
        let stack = hstack([icon, textStack], spacing: 14)
        stack.alignment = .centerY
        return stack
    }

    private func makePermissionCard() -> NSView {
        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 34),
            icon.heightAnchor.constraint(equalToConstant: 34)
        ])
        permissionIconView = icon
        let titleLabel = label("Accessibility Access", size: 13, weight: .semibold)
        let descLabel = label("", size: 12)
        descLabel.textColor = .secondaryLabelColor
        descLabel.maximumNumberOfLines = 3
        permissionDescLabel = descLabel
        let badge = label("", size: 11, weight: .semibold)
        permissionBadgeLabel = badge
        let textStack = vstack([titleLabel, descLabel], spacing: 2)
        let topRow = hstack([icon, textStack, badge], spacing: 12)
        topRow.alignment = .centerY
        let settingsBtn = NSButton(title: "Open System Settings", target: self, action: #selector(openSettings))
        settingsBtn.bezelStyle = .rounded
        let checkBtn = NSButton(title: "Check Again", target: self, action: #selector(checkPermission))
        checkBtn.bezelStyle = .rounded
        let btnRow = hstack([settingsBtn, checkBtn], spacing: 10)
        return card(vstack([topRow, btnRow], spacing: 14))
    }

    private func makeInstructionsCard() -> NSView {
        let content = vstack([
            label("How it works", size: 13, weight: .semibold),
            instructionRow("1", "Grant Accessibility access in System Settings."),
            instructionRow("2", "Leave AltTab running in the background."),
            instructionRow("3", "Hold Option and press Tab to cycle windows, then release Option to focus the selected one.")
        ], spacing: 10)
        return card(content)
    }

    private func makeFooter() -> NSView {
        let hint = label("", size: 12, weight: .medium)
        shortcutLabel = hint
        let sub = label("Press Esc while the switcher is visible to cancel without changing windows.", size: 11)
        sub.textColor = .secondaryLabelColor
        return vstack([hint, sub], spacing: 4)
    }

    private func instructionRow(_ number: String, _ text: String) -> NSView {
        let numLabel = label(number, size: 11, weight: .semibold)
        numLabel.textColor = .controlAccentColor
        numLabel.alignment = .center
        let circle = NSView()
        circle.wantsLayer = true
        circle.layer?.cornerRadius = 10
        circle.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.14).cgColor
        circle.translatesAutoresizingMaskIntoConstraints = false
        numLabel.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(numLabel)
        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: 20),
            circle.heightAnchor.constraint(equalToConstant: 20),
            numLabel.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            numLabel.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
        ])
        let textLabel = label(text, size: 13)
        textLabel.maximumNumberOfLines = 3
        circle.setAccessibilityElement(false)
        numLabel.setAccessibilityElement(false)
        textLabel.setAccessibilityLabel("Step \(number): \(text)")
        let row = hstack([circle, textLabel], spacing: 10)
        row.alignment = .centerY
        return row
    }

    private func card(_ content: NSView) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        container.layer?.cornerRadius = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -18)
        ])
        return container
    }

    private func label(_ string: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSTextField {
        let field = NSTextField(labelWithString: string)
        field.font = .systemFont(ofSize: size, weight: weight)
        return field
    }

    private func hstack(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = spacing
        return stack
    }

    private func vstack(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }

    @objc private func openSettings() {
        appController?.requestAccessibilityAccess()
    }

    @objc private func checkPermission() {
        appController?.refreshPermissionStatus()
        refresh()
    }
}
