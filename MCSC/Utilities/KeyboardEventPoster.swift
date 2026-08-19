import Cocoa

enum KeyboardEventPoster {
    static func postShortcut(virtualKey: CGKeyCode, flags: CGEventFlags, to pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
        keyDown?.flags = flags
        keyUp?.flags = flags
        keyDown?.postToPid(pid)
        keyUp?.postToPid(pid)
    }
}
