import Foundation
import CoreGraphics
import ApplicationServices
import Carbon

public enum AccessibilityHelper {
    public static func isTrusted(promptIfNeeded: Bool) -> Bool {
        if promptIfNeeded {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options: NSDictionary = [key: true]
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    public static func isSecureEventInputEnabled() -> Bool {
        IsSecureEventInputEnabled()
    }
}

public final class KeyboardHibernator {
    // NX_SYSDEFINED (volume, brightness, media play/pause, dictation, spotlight, etc.)
    private static let systemDefinedEventRawValue: UInt32 = 14

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var selfPtr: UnsafeMutableRawPointer?

    private var wakeHoldTimer: DispatchSourceTimer?
    private var wakeHoldStart: Date?

    public let lockMouse: Bool
    public let wakeHoldDuration: TimeInterval

    public private(set) var isHibernating = false
    private var isUnlocking = false

    public var onWakeHoldProgress: ((Double) -> Void)?
    public var onUnlockTriggered: ((WakeReason) -> Void)?

    public init(lockMouse: Bool = false, wakeHoldDuration: TimeInterval = AppMeta.wakeHoldDuration) {
        self.lockMouse = lockMouse
        self.wakeHoldDuration = max(0.0, wakeHoldDuration)
    }

    private static let tapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon = refcon else {
            return Unmanaged.passRetained(event)
        }
        let hibernator = Unmanaged<KeyboardHibernator>.fromOpaque(refcon).takeUnretainedValue()
        return hibernator.handleEvent(type: type, event: event)
    }

    func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isHibernating else {
            return Unmanaged.passRetained(event)
        }

        if type == .tapDisabledByTimeout {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return nil
        }

        if type == .tapDisabledByUserInput {
            if !isUnlocking {
                isUnlocking = true
                cancelWakeHoldTimer()
                DispatchQueue.main.async { [weak self] in
                    self?.onUnlockTriggered?(.systemDisabled)
                }
            }
            return nil
        }

        if type == .flagsChanged {
            let flags = event.flags
            let hasAllWakeModifiers =
                flags.contains(.maskControl) &&
                flags.contains(.maskAlternate) &&
                flags.contains(.maskCommand)

            if hasAllWakeModifiers {
                beginWakeHoldIfNeeded()
            } else {
                cancelWakeHoldIfActive()
            }
            return nil
        }

        if type == .keyDown || type == .keyUp || type.rawValue == Self.systemDefinedEventRawValue {
            return nil
        }

        if lockMouse && Self.isMouseEventType(type) {
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    public static func isMouseEventType(_ type: CGEventType) -> Bool {
        switch type {
        case .leftMouseDown, .leftMouseUp,
             .rightMouseDown, .rightMouseUp,
             .otherMouseDown, .otherMouseUp,
             .mouseMoved,
             .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
             .scrollWheel:
            return true
        default:
            return false
        }
    }

    public static func buildEventMask(lockMouse: Bool) -> CGEventMask {
        var mask: CGEventMask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue) |
            (CGEventMask(1) << CGEventType.keyUp.rawValue) |
            (CGEventMask(1) << CGEventType.flagsChanged.rawValue) |
            (CGEventMask(1) << systemDefinedEventRawValue)

        if lockMouse {
            let mouseTypes: [CGEventType] = [
                .leftMouseDown, .leftMouseUp,
                .rightMouseDown, .rightMouseUp,
                .otherMouseDown, .otherMouseUp,
                .mouseMoved,
                .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
                .scrollWheel
            ]
            for mouseType in mouseTypes {
                mask |= (CGEventMask(1) << mouseType.rawValue)
            }
        }

        return mask
    }

    private func beginWakeHoldIfNeeded() {
        guard !isUnlocking else { return }

        if wakeHoldDuration <= 0.0 {
            completeWakeHold()
            return
        }

        guard wakeHoldTimer == nil else { return }

        let start = Date()
        wakeHoldStart = start

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(40), leeway: .milliseconds(10))
        timer.setEventHandler { [weak self] in
            guard let self = self, self.isHibernating, !self.isUnlocking else { return }
            let elapsed = Date().timeIntervalSince(start)
            let progress = min(1.0, elapsed / self.wakeHoldDuration)
            self.onWakeHoldProgress?(progress)
            if elapsed >= self.wakeHoldDuration {
                self.completeWakeHold()
            }
        }
        wakeHoldTimer = timer
        timer.resume()
    }

    private func cancelWakeHoldIfActive() {
        guard wakeHoldTimer != nil else { return }
        cancelWakeHoldTimer()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isHibernating, !self.isUnlocking else { return }
            self.onWakeHoldProgress?(0.0)
        }
    }

    private func completeWakeHold() {
        guard !isUnlocking else { return }
        isUnlocking = true
        cancelWakeHoldTimer()
        DispatchQueue.main.async { [weak self] in
            self?.onWakeHoldProgress?(1.0)
            self?.onUnlockTriggered?(.wakeChord)
        }
    }

    private func cancelWakeHoldTimer() {
        wakeHoldTimer?.setEventHandler {}
        wakeHoldTimer?.cancel()
        wakeHoldTimer = nil
        wakeHoldStart = nil
    }

    public func startHibernating() -> Bool {
        guard !isHibernating else { return true }
        isUnlocking = false

        let eventMask = Self.buildEventMask(lockMouse: lockMouse)
        let ptr = Unmanaged.passRetained(self).toOpaque()
        selfPtr = ptr

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: Self.tapCallback,
            userInfo: ptr
        ) else {
            Unmanaged<KeyboardHibernator>.fromOpaque(ptr).release()
            selfPtr = nil
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isHibernating = true
        return true
    }

    public func stopHibernating() {
        cancelWakeHoldTimer()
        guard isHibernating else {
            isUnlocking = false
            return
        }

        isHibernating = false
        isUnlocking = false

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil

        if let ptr = selfPtr {
            selfPtr = nil
            Unmanaged<KeyboardHibernator>.fromOpaque(ptr).release()
        }
    }

    deinit {
        stopHibernating()
    }
}
