import AppKit
import Carbon.HIToolbox

final class HotKeyCenter {
    var onTrigger: (() -> Void)?
    var onModifierRelease: (() -> Void)?
    var onEscape: (() -> Void)?
    var onRegistrationFailure: ((String) -> Void)?

    private var eventHandler: EventHandlerRef?
    private var forwardHotKey: EventHotKeyRef?
    private var monitors: [Any] = []
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true

        guard installHandler(), registerHotKeys() else {
            stop()
            return
        }
    }

    func beginSwitcherSession() {
        guard monitors.isEmpty else { return }
        installMonitors()
    }

    func endSwitcherSession() {
        removeMonitors()
    }

    func stop() {
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        if let forwardHotKey {
            UnregisterEventHotKey(forwardHotKey)
            self.forwardHotKey = nil
        }

        removeMonitors()
        isStarted = false
    }

    @discardableResult
    private func installHandler() -> Bool {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandlerUPP,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard status == noErr else {
            onRegistrationFailure?("Could not install the global hotkey handler.")
            return false
        }

        return true
    }

    @discardableResult
    private func registerHotKeys() -> Bool {
        let signature = fourCharCode("ATSW")

        let forwardID = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_Tab),
            UInt32(optionKey),
            forwardID,
            GetApplicationEventTarget(),
            0,
            &forwardHotKey
        )

        guard status == noErr else {
            if status == eventHotKeyExistsErr {
                onRegistrationFailure?("Option + Tab is already being used by another app.")
            } else {
                onRegistrationFailure?("Could not register Option + Tab as a global shortcut.")
            }
            return false
        }

        return true
    }

    private func installMonitors() {
        let globalFlags = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        let localFlags = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
        let globalKeys = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
        }
        let localKeys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
            return event
        }

        if let globalFlags { monitors.append(globalFlags) }
        if let localFlags { monitors.append(localFlags) }
        if let globalKeys { monitors.append(globalKeys) }
        if let localKeys { monitors.append(localKeys) }
    }

    private func removeMonitors() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if !flags.contains(.option) {
            onModifierRelease?()
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard event.keyCode == UInt16(kVK_Escape) else { return }
        onEscape?()
    }

    private func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr else { return status }

        switch hotKeyID.id {
        case 1:
            onTrigger?()
        default:
            break
        }

        return noErr
    }

    private static let eventHandlerUPP: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else { return noErr }

        let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
        return center.handleHotKeyEvent(event)
    }

    private func fourCharCode(_ string: String) -> OSType {
        string.utf16.reduce(0) { partialResult, character in
            (partialResult << 8) + OSType(character)
        }
    }
}
