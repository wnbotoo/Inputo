import AppKit
import Carbon.HIToolbox

public struct GlobalShortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32
    public var displayKey: String

    public init(keyCode: UInt32, carbonModifiers: UInt32, displayKey: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.displayKey = displayKey
    }

    public var displayText: String {
        var parts: [String] = []
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        parts.append(displayKey.uppercased())
        return parts.joined()
    }

    public static func from(event: NSEvent) -> GlobalShortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbonModifiers: UInt32 = 0
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }

        guard carbonModifiers != 0 else { return nil }

        let displayKey = event.charactersIgnoringModifiers?.uppercased() ?? String(event.keyCode)
        return GlobalShortcut(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: carbonModifiers,
            displayKey: displayKey
        )
    }
}
