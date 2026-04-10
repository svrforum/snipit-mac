import Carbon.HIToolbox
import Foundation

struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let fullScreenCapture = HotkeyConfig(
        keyCode: UInt32(kVK_ANSI_A),
        modifiers: UInt32(controlKey | optionKey)
    )

    static let regionCapture = HotkeyConfig(
        keyCode: UInt32(kVK_ANSI_S),
        modifiers: UInt32(controlKey | optionKey)
    )

    static let windowCapture = HotkeyConfig(
        keyCode: UInt32(kVK_ANSI_W),
        modifiers: UInt32(controlKey | optionKey)
    )

    static let scrollCapture = HotkeyConfig(
        keyCode: UInt32(kVK_ANSI_D),
        modifiers: UInt32(controlKey | optionKey)
    )

    static let gifRecording = HotkeyConfig(
        keyCode: UInt32(kVK_ANSI_G),
        modifiers: UInt32(controlKey | optionKey)
    )

    static let mp4Recording = HotkeyConfig(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(controlKey | optionKey)
    )
}
