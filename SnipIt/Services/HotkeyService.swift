import AppKit
import Carbon.HIToolbox

// MARK: - HotkeyHandlers

struct HotkeyHandlers {
    var fullScreen: () -> Void = {}
    var region: () -> Void = {}
    var window: () -> Void = {}
    var scroll: () -> Void = {}
    var gifRecord: () -> Void = {}
    var mp4Record: () -> Void = {}
}

// MARK: - HotkeyService

final class HotkeyService {

    static let shared = HotkeyService()

    // MARK: - Properties

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?

    // Carbon signature for SnipIt: "SNIT"
    private let hotKeySignature: UInt32 = {
        let s = "SNIT"
        let bytes = Array(s.utf8)
        return UInt32(bytes[0]) << 24
            | UInt32(bytes[1]) << 16
            | UInt32(bytes[2]) << 8
            | UInt32(bytes[3])
    }()

    // MARK: - Initialization

    private init() {
        installEventHandler()
    }

    deinit {
        unregisterAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    // MARK: - Registration

    /// Register a hotkey with a raw key code and Carbon modifier mask.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool {
        let hotkeyID = EventHotKeyID(signature: hotKeySignature, id: nextID)
        let carbonModifiers = carbonModifierFlags(from: modifiers)

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else {
            return false
        }

        handlers[nextID] = handler
        hotKeyRefs.append(ref)
        nextID += 1
        return true
    }

    /// Convenience: register from a HotkeyConfig.
    @discardableResult
    func register(config: HotkeyConfig, handler: @escaping () -> Void) -> Bool {
        register(keyCode: config.keyCode, modifiers: config.modifiers, handler: handler)
    }

    // MARK: - Unregister

    func unregisterAll() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        handlers.removeAll()
        nextID = 1
    }

    // MARK: - Re-register

    /// Unregisters all hotkeys, then registers the 6 configured hotkeys from settings.
    func reregister(settings: AppSettings, handlers hotkeyHandlers: HotkeyHandlers) {
        unregisterAll()

        register(config: settings.hotkeyFullScreen, handler: hotkeyHandlers.fullScreen)
        register(config: settings.hotkeyRegion, handler: hotkeyHandlers.region)
        register(config: settings.hotkeyWindow, handler: hotkeyHandlers.window)
        register(config: settings.hotkeyScroll, handler: hotkeyHandlers.scroll)
        register(config: settings.hotkeyGif, handler: hotkeyHandlers.gifRecord)
        register(config: settings.hotkeyMp4, handler: hotkeyHandlers.mp4Record)
    }

    // MARK: - Event Handler Installation

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData, let event else { return OSStatus(eventNotHandledErr) }

                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()

                var hotkeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )

                guard status == noErr else { return status }

                if let handler = service.handlers[hotkeyID.id] {
                    DispatchQueue.main.async {
                        handler()
                    }
                }

                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )
    }

    // MARK: - Helpers

    /// Convert Carbon modifier constants (controlKey, optionKey, etc.) to
    /// the modifier mask format expected by RegisterEventHotKey.
    private func carbonModifierFlags(from modifiers: UInt32) -> UInt32 {
        var result: UInt32 = 0
        if modifiers & UInt32(controlKey) != 0 {
            result |= UInt32(controlKey)
        }
        if modifiers & UInt32(optionKey) != 0 {
            result |= UInt32(optionKey)
        }
        if modifiers & UInt32(shiftKey) != 0 {
            result |= UInt32(shiftKey)
        }
        if modifiers & UInt32(cmdKey) != 0 {
            result |= UInt32(cmdKey)
        }
        return result
    }
}
