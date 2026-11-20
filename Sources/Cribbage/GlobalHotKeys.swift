import Carbon.HIToolbox

@MainActor
enum GlobalHotKeys {
    private static let signature = OSType(0x4352_4942)
    private static var actions: [UInt32: () -> Void] = [:]
    private static var handlerRef: EventHandlerRef?

    static func register(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        installHandlerIfNeeded()
        let id = UInt32(actions.count + 1)
        actions[id] = action
        var hotKeyRef: EventHotKeyRef?
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), EventHotKeyID(signature: signature, id: id), GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private static func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), handleEvent, 1, &eventType, nil, &handlerRef)
    }

    private static let handleEvent: EventHandlerUPP = { _, event, _ in
        guard let event else { return OSStatus(eventNotHandledErr) }
        var pressed = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &pressed
        )
        guard status == noErr, pressed.signature == signature else { return OSStatus(eventNotHandledErr) }
        let id = pressed.id
        return MainActor.assumeIsolated {
            guard let action = actions[id] else { return OSStatus(eventNotHandledErr) }
            action()
            return noErr
        }
    }
}
