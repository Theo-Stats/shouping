import AppKit
import CoreGraphics
import ShoupingCore

enum InputGateError: LocalizedError {
    case permissionDenied
    case tapCreationFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "键盘锁定需要“辅助功能”和“输入监控”权限。请在系统设置中授权后重试。"
        case .tapCreationFailed:
            return "系统拒绝创建键盘事件过滤器。电脑仍可使用全屏遮挡模式。"
        }
    }
}

private let inputGateCallback: CGEventTapCallBack = { _, type, event, userInfo in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        return Unmanaged.passUnretained(event)
    }

    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let gate = Unmanaged<InputGate>.fromOpaque(userInfo).takeUnretainedValue()
    let flags = event.flags
    let isEmergency = type == .keyDown
        && EmergencyShortcut.matches(
            control: flags.contains(.maskControl),
            command: flags.contains(.maskCommand),
            keyCode: event.getIntegerValueField(.keyboardEventKeycode)
        )

    if isEmergency {
        gate.requestEmergencyUnlock()
        return nil
    }

    switch type {
    case .keyDown, .keyUp, .flagsChanged, .scrollWheel:
        return nil
    default:
        return Unmanaged.passUnretained(event)
    }
}

final class InputGate {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let onEmergency: @MainActor () -> Void

    init(onEmergency: @escaping @MainActor () -> Void) {
        self.onEmergency = onEmergency
    }

    var isRunning: Bool {
        eventTap != nil
    }

    func start() throws {
        guard eventTap == nil else { return }

        let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(promptOptions),
              CGPreflightListenEventAccess() || CGRequestListenEventAccess() else {
            throw InputGateError.permissionDenied
        }

        let eventTypes: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .scrollWheel]
        let mask = eventTypes.reduce(CGEventMask(0)) { result, type in
            result | (CGEventMask(1) << CGEventMask(type.rawValue))
        }

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: inputGateCallback,
            userInfo: userInfo
        ) else {
            throw InputGateError.tapCreationFailed
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        self.eventTap = eventTap
        self.runLoopSource = source
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
    }

    fileprivate func requestEmergencyUnlock() {
        DispatchQueue.main.async { [onEmergency] in
            Task { @MainActor in
                onEmergency()
            }
        }
    }
}
