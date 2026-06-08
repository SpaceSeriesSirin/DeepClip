import Carbon
import AppKit

/// Registers a single system-wide global hotkey using the Carbon Event Manager
/// (`RegisterEventHotKey`). This requires no external dependencies and does not
/// need Accessibility permissions (unlike a global `CGEventTap`).
///
/// Usage:
/// ```
/// HotkeyService.shared.onTrigger = { /* summon UI */ }
/// HotkeyService.shared.currentHotkey = .init(keyCode: 9, modifiers: [.command, .shift])
/// HotkeyService.shared.register()
/// ```
final class HotkeyService {
    static let shared = HotkeyService()

    struct Hotkey: Equatable {
        var keyCode: Int
        var modifiers: NSEvent.ModifierFlags
    }

    /// Default: ⌘⇧V (kVK_ANSI_V == 9).
    var currentHotkey = Hotkey(keyCode: 9, modifiers: [.command, .shift])

    /// Invoked on the main thread whenever the hotkey fires.
    var onTrigger: (() -> Void)?

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var isRegistered = false

    // A stable signature/id so our handler only reacts to our own hotkey.
    private let hotkeyID = EventHotKeyID(signature: OSType(0x434C4950 /* "CLIP" */), id: 1)

    private init() {}

    deinit {
        unregister()
    }

    // MARK: - Registration

    /// (Re)registers the current hotkey. Safe to call repeatedly — it tears down
    /// any existing registration first. No-op if `keyCode`/`modifiers` are empty.
    @discardableResult
    func register() -> Bool {
        unregister()

        // A modifier-less hotkey would fire on every press of the key; require
        // at least one modifier to avoid hijacking normal typing.
        let carbonModifiers = Self.carbonModifiers(from: currentHotkey.modifiers)
        guard carbonModifiers != 0 else {
            AppLogger.app.error("Refusing to register hotkey without modifiers")
            return false
        }

        installHandlerIfNeeded()

        let status = RegisterEventHotKey(
            UInt32(currentHotkey.keyCode),
            carbonModifiers,
            hotkeyID,
            GetEventDispatcherTarget(),
            0,
            &hotkeyRef
        )

        guard status == noErr, hotkeyRef != nil else {
            AppLogger.app.error("RegisterEventHotKey failed (status \(status))")
            return false
        }

        isRegistered = true
        return true
    }

    /// Unregisters the hotkey (does not remove the shared event handler).
    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        isRegistered = false
    }

    /// Convenience: update the hotkey and re-register in one call.
    func update(to hotkey: Hotkey) {
        currentHotkey = hotkey
        register()
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // `userData` carries an unretained pointer back to `self`.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var firedID = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &firedID
                )
                guard err == noErr else { return err }

                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                guard firedID.signature == service.hotkeyID.signature,
                      firedID.id == service.hotkeyID.id else {
                    return noErr
                }

                DispatchQueue.main.async {
                    service.onTrigger?()
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }

    // MARK: - Modifier translation

    /// Converts `NSEvent.ModifierFlags` to the Carbon modifier bitmask expected
    /// by `RegisterEventHotKey`.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        return carbon
    }

    // MARK: - Human-readable description

    /// Returns a glyph string for the hotkey, e.g. "⌘⇧V".
    static func displayString(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String {
        var parts = ""
        if modifiers.contains(.control) { parts += "⌃" }
        if modifiers.contains(.option)  { parts += "⌥" }
        if modifiers.contains(.shift)   { parts += "⇧" }
        if modifiers.contains(.command) { parts += "⌘" }
        parts += keyName(for: keyCode)
        return parts
    }

    static func displayString(for hotkey: Hotkey) -> String {
        displayString(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers)
    }

    /// Maps a virtual key code to a printable label. Covers the common keys; any
    /// unmapped code falls back to a numeric placeholder.
    static func keyName(for keyCode: Int) -> String {
        if let special = specialKeyNames[keyCode] { return special }
        if let char = characterForKeyCode(keyCode) { return char.uppercased() }
        return "Key \(keyCode)"
    }

    private static let specialKeyNames: [Int: String] = [
        36:  "↩",      // Return
        48:  "⇥",      // Tab
        49:  "Space",
        51:  "⌫",      // Delete
        53:  "⎋",      // Escape
        117: "⌦",      // Forward Delete
        123: "←",
        124: "→",
        125: "↓",
        126: "↑",
        116: "Page Up",
        121: "Page Down",
        115: "Home",
        119: "End",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]

    /// Best-effort translation of a key code to its character using the current
    /// keyboard layout (so it works for non-US layouts too).
    private static func characterForKeyCode(_ keyCode: Int) -> String? {
        guard let layoutData = TISGetInputSourceProperty(
            TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue(),
            kTISPropertyUnicodeKeyLayoutData
        ) else { return nil }

        let data = unsafeBitCast(layoutData, to: CFData.self)
        let keyLayout = unsafeBitCast(CFDataGetBytePtr(data), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)

        let status = UCKeyTranslate(
            keyLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
