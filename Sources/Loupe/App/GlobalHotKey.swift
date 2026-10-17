import Carbon.HIToolbox

@MainActor final class GlobalHotKey {
    struct Shortcut {
        let keyCode: Int
        let modifiers: Int
        let symbol: String

        static let record = Shortcut(keyCode: kVK_ANSI_R, modifiers: optionKey | shiftKey | cmdKey, symbol: "⌥⇧⌘R")
    }

    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    private var reference: EventHotKeyRef?
    private let id: UInt32

    init?(_ shortcut: Shortcut, action: @escaping () -> Void) {
        id = Self.nextID
        Self.nextID += 1
        Self.installHandler()
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            UInt32(shortcut.modifiers),
            EventHotKeyID(signature: OSType(0x4C4F5550), id: id),
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr else { return nil }
        Self.actions[id] = action
    }

    isolated deinit {
        reference.map { _ = UnregisterEventHotKey($0) }
        Self.actions[id] = nil
    }

    private static func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKey = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
            MainActor.assumeIsolated { GlobalHotKey.actions[hotKey.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
