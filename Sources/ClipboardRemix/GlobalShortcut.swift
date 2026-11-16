import AppKit
import Carbon

@MainActor final class GlobalShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, pointer in
            guard let pointer else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<GlobalShortcut>.fromOpaque(pointer).takeUnretainedValue()
            MainActor.assumeIsolated { owner.onPress?() }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    @discardableResult func register(shift: Bool) -> Bool {
        // Register the new choice before relinquishing the working shortcut.
        var next: EventHotKeyRef?
        let flags = UInt32(cmdKey | optionKey | (shift ? shiftKey : 0))
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_V), flags, EventHotKeyID(signature: 0x434C4950, id: shift ? 2 : 1), GetApplicationEventTarget(), 0, &next)
        guard result == noErr else { return false }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = next; return true
    }
    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
