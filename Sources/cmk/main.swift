import Foundation
import CoreGraphics
import AppKit

// MARK: - ANSI Colors & Styling
struct ANSI {
    static let reset     = "\u{001B}[0m"
    static let bold      = "\u{001B}[1m"
    static let dim       = "\u{001B}[2m"
    static let red       = "\u{001B}[31m"
    static let green     = "\u{001B}[32m"
    static let yellow    = "\u{001B}[33m"
    static let blue      = "\u{001B}[34m"
    static let magenta   = "\u{001B}[35m"
    static let cyan      = "\u{001B}[36m"
    static let white     = "\u{001B}[37m"
    static let bgBlack   = "\u{001B}[40m"
    static let clearLine = "\u{001B}[2K\r"
    static let hideCursor = "\u{001B}[?25l"
    static let showCursor = "\u{001B}[?25h"
    static let moveUp    = "\u{001B}[1A"
}

// MARK: - Sound Player
func playSound(_ name: String) {
    if let sound = NSSound(named: NSSound.Name(name)) {
        sound.play()
        Thread.sleep(forTimeInterval: sound.duration + 0.1)
    } else {
        // Fallback: system beep
        NSSound.beep()
    }
}

func playLockSound() {
    // Try a soft notification sound
    for name in ["Funk", "Pop", "Tink", "Morse"] {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.volume = 0.4
            sound.play()
            Thread.sleep(forTimeInterval: sound.duration + 0.05)
            return
        }
    }
    NSSound.beep()
}

func playUnlockSound() {
    for name in ["Glass", "Hero", "Ping", "Purr"] {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.volume = 0.4
            sound.play()
            Thread.sleep(forTimeInterval: sound.duration + 0.05)
            return
        }
    }
    NSSound.beep()
}

// MARK: - macOS Notification
func sendNotification(title: String, message: String) {
    let script = """
    display notification "\(message)" with title "\(title)" sound name "default"
    """
    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", script]
    try? task.run()
}

// MARK: - Permission Check
func checkAccessibilityPermission() -> Bool {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
    return AXIsProcessTrustedWithOptions(options)
}

// MARK: - Keyboard Blocker
class KeyboardBlocker {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isBlocking = false

    static let unlockCombo: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]

    var onUnlockTriggered: (() -> Void)?

    private let callback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon = refcon else { return Unmanaged.passRetained(event) }
        let blocker = Unmanaged<KeyboardBlocker>.fromOpaque(refcon).takeUnretainedValue()

        // Allow only system events through when blocking
        if type == .keyDown || type == .keyUp || type == .flagsChanged {
            let flags = event.flags
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            // Ctrl + Option + Cmd + Space (keyCode 49 = Space)
            let isUnlockCombo = flags.contains(.maskControl) &&
                                 flags.contains(.maskAlternate) &&
                                 flags.contains(.maskCommand) &&
                                 keyCode == 49 &&
                                 type == .keyDown

            if isUnlockCombo {
                DispatchQueue.main.async {
                    blocker.onUnlockTriggered?()
                }
                return nil // consume this event too
            }

            return nil // block all keyboard input
        }

        return Unmanaged.passRetained(event)
    }

    func startBlocking() -> Bool {
        guard !isBlocking else { return true }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                      (1 << CGEventType.keyUp.rawValue) |
                                      (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isBlocking = true
        return true
    }

    func stopBlocking() {
        guard isBlocking, let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isBlocking = false
    }
}

// MARK: - UI Drawing
func clearScreen() {
    print("\u{001B}[2J\u{001B}[H", terminator: "")
}

func printBanner() {
    let banner = """
    \(ANSI.cyan)\(ANSI.bold)
    ╔═══════════════════════════════════════════╗
    ║         🧹  CleanMyKeyboard  🧹           ║
    ║              \(ANSI.dim)github.com/cmk-app\(ANSI.reset)\(ANSI.cyan)\(ANSI.bold)              ║
    ╚═══════════════════════════════════════════╝\(ANSI.reset)
    """
    print(banner)
}

func printCountdown(_ seconds: Int) {
    let bar = buildProgressBar(current: 10 - seconds, total: 10, width: 33)
    let color = seconds > 5 ? ANSI.yellow : ANSI.red
    print("\(ANSI.clearLine)\(ANSI.bold)  \(color)⏱  Disabling keyboard in  \(ANSI.white)\(seconds)s\(ANSI.reset)  \(bar)", terminator: "")
    fflush(stdout)
}

func buildProgressBar(current: Int, total: Int, width: Int) -> String {
    let filled = Int(Double(current) / Double(total) * Double(width))
    let empty = width - filled
    let filledStr = String(repeating: "█", count: max(0, filled))
    let emptyStr  = String(repeating: "░", count: max(0, empty))
    return "\(ANSI.cyan)[\(filledStr)\(ANSI.dim)\(emptyStr)\(ANSI.reset)\(ANSI.cyan)]\(ANSI.reset)"
}

func printLocked() {
    clearScreen()
    printBanner()
    print("""

    \(ANSI.green)\(ANSI.bold)  ╔══════════════════════════════════════════╗
      ║   🔒  Keyboard is LOCKED — Safe to Clean!  ║
      ╚══════════════════════════════════════════╝\(ANSI.reset)

    \(ANSI.dim)  Wipe away! No accidental keypresses will get through.

    \(ANSI.yellow)  To unlock:\(ANSI.reset)\(ANSI.white)  Ctrl + Option + Cmd + Space\(ANSI.reset)

    \(ANSI.dim)  ─────────────────────────────────────────────\(ANSI.reset)
    """)
}

func printUnlocked() {
    clearScreen()
    printBanner()
    print("""

    \(ANSI.green)\(ANSI.bold)  ✅  Keyboard reactivated! You're good to go.\(ANSI.reset)

    \(ANSI.dim)  Thanks for using CleanMyKeyboard.
      Run \(ANSI.reset)\(ANSI.cyan)cmk\(ANSI.dim) anytime you want to clean again.\(ANSI.reset)

    """)
}

// MARK: - App Entry Point
func runApp() {
    // Accessibility check
    if !AXIsProcessTrusted() {
        clearScreen()
        printBanner()
        print("""

    \(ANSI.yellow)\(ANSI.bold)  ⚠️  Accessibility Permission Required\(ANSI.reset)

    \(ANSI.white)  cmk needs Accessibility access to block keyboard input.\(ANSI.reset)

    \(ANSI.dim)  A system dialog has been shown — please:
      1. Open System Settings → Privacy & Security → Accessibility
      2. Enable your Terminal (or iTerm2) in the list
      3. Run \(ANSI.reset)\(ANSI.cyan)cmk\(ANSI.dim) again\(ANSI.reset)

    """)
        _ = checkAccessibilityPermission() // triggers the prompt
        exit(1)
    }

    // Hide cursor for cleaner UI
    print(ANSI.hideCursor, terminator: "")

    clearScreen()
    printBanner()

    print("""

    \(ANSI.white)  Preparing to lock your keyboard for cleaning...\(ANSI.reset)
    \(ANSI.dim)  Press \(ANSI.reset)\(ANSI.red)Ctrl+C\(ANSI.dim) to cancel before the countdown ends.\(ANSI.reset)

    """)

    // Countdown
    for i in stride(from: 10, through: 1, by: -1) {
        printCountdown(i)
        Thread.sleep(forTimeInterval: 1.0)
    }
    print() // newline after countdown

    // Lock keyboard
    let blocker = KeyboardBlocker()
    var unlocked = false

    blocker.onUnlockTriggered = {
        unlocked = true
        blocker.stopBlocking()

        DispatchQueue.global().async {
            printUnlocked()
            playUnlockSound()
            sendNotification(
                title: "CleanMyKeyboard",
                message: "⌨️ Keyboard is active again — ready to use!"
            )
            print(ANSI.showCursor, terminator: "")
            fflush(stdout)
            Thread.sleep(forTimeInterval: 1.5)
            exit(0)
        }
    }

    guard blocker.startBlocking() else {
        print("""

    \(ANSI.red)  ✗ Failed to create keyboard event tap.\(ANSI.reset)
    \(ANSI.dim)  Make sure Accessibility permission is granted and try again.\(ANSI.reset)

    """)
        print(ANSI.showCursor, terminator: "")
        exit(1)
    }

    // Show locked UI
    printLocked()
    playLockSound()
    sendNotification(
        title: "CleanMyKeyboard",
        message: "🔒 Keyboard locked — safe to clean! Press ⌃⌥⌘Space to unlock."
    )

    // Run the main loop
    RunLoop.main.run()
}

// Handle Ctrl+C gracefully
signal(SIGINT) { _ in
    print("\n\n\(ANSI.showCursor)\(ANSI.yellow)  Cancelled — keyboard was not locked.\(ANSI.reset)\n")
    exit(0)
}

runApp()
