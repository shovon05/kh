import Foundation
import CoreGraphics
import AppKit

// MARK: - ANSI Colors & Styling
struct ANSI {
    static let reset      = "\u{001B}[0m"
    static let bold       = "\u{001B}[1m"
    static let dim        = "\u{001B}[2m"
    static let red        = "\u{001B}[31m"
    static let green      = "\u{001B}[32m"
    static let yellow     = "\u{001B}[33m"
    static let blue       = "\u{001B}[34m"
    static let magenta    = "\u{001B}[35m"
    static let cyan       = "\u{001B}[36m"
    static let white      = "\u{001B}[37m"
    static let bgBlack    = "\u{001B}[40m"
    static let clearLine  = "\u{001B}[2K\r"
    static let hideCursor = "\u{001B}[?25l"
    static let showCursor = "\u{001B}[?25h"
    static let moveUp     = "\u{001B}[1A"
}

// MARK: - Sound Player
func playLockSound() {
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

// MARK: - Keyboard Hibernator
//
// Unlock combo: Ctrl + Option + Cmd  (hold all three simultaneously)
// Space is intentionally excluded — every key is blocked during hibernate.
// The combo is detected on flagsChanged only (modifier keys), so no
// regular keyCode is needed and no key can slip through.
//
class KeyboardHibernator {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isHibernating = false

    var onUnlockTriggered: (() -> Void)?

    // We detect the unlock chord purely on modifier flags so that *every*
    // regular key (including Space) stays completely blocked.
    private let callback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon = refcon else { return Unmanaged.passRetained(event) }
        let hibernator = Unmanaged<KeyboardHibernator>.fromOpaque(refcon).takeUnretainedValue()

        switch type {
        case .flagsChanged:
            // Unlock when Ctrl + Option + Cmd are ALL held — nothing else required.
            let flags = event.flags
            let hasCtrl  = flags.contains(.maskControl)
            let hasAlt   = flags.contains(.maskAlternate)
            let hasCmd   = flags.contains(.maskCommand)

            if hasCtrl && hasAlt && hasCmd {
                DispatchQueue.main.async {
                    hibernator.onUnlockTriggered?()
                }
            }
            // Block the modifier event itself so it doesn't leak through
            return nil

        case .keyDown, .keyUp:
            // Block every single key — no exceptions
            return nil

        default:
            return Unmanaged.passRetained(event)
        }
    }

    func startHibernating() -> Bool {
        guard !isHibernating else { return true }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)   |
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
        isHibernating = true
        return true
    }

    func stopHibernating() {
        guard isHibernating, let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isHibernating = false
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
    ║        ❄️   KeyboardHibernate   ❄️         ║
    ║          \(ANSI.dim)github.com/shovon05/kh\(ANSI.reset)\(ANSI.cyan)\(ANSI.bold)            ║
    ╚═══════════════════════════════════════════╝\(ANSI.reset)
    """
    print(banner)
}

func printCountdown(_ seconds: Int) {
    let bar = buildProgressBar(current: 10 - seconds, total: 10, width: 33)
    let color = seconds > 5 ? ANSI.yellow : ANSI.red
    print("\(ANSI.clearLine)\(ANSI.bold)  \(color)⏱  Hibernating keyboard in  \(ANSI.white)\(seconds)s\(ANSI.reset)  \(bar)", terminator: "")
    fflush(stdout)
}

func buildProgressBar(current: Int, total: Int, width: Int) -> String {
    let filled = Int(Double(current) / Double(total) * Double(width))
    let empty  = width - filled
    let filledStr = String(repeating: "█", count: max(0, filled))
    let emptyStr  = String(repeating: "░", count: max(0, empty))
    return "\(ANSI.cyan)[\(filledStr)\(ANSI.dim)\(emptyStr)\(ANSI.reset)\(ANSI.cyan)]\(ANSI.reset)"
}

func printHibernating() {
    clearScreen()
    printBanner()
    print("""

    \(ANSI.cyan)\(ANSI.bold)  ╔══════════════════════════════════════════════╗
      ║   ❄️  Keyboard is HIBERNATING — Safe to Clean!  ║
      ╚══════════════════════════════════════════════╝\(ANSI.reset)

    \(ANSI.dim)  Every key is fully blocked — wipe away freely.
      No modifier, no Space, no key of any kind will register.\(ANSI.reset)

    \(ANSI.yellow)  To wake up:\(ANSI.reset)\(ANSI.white)  Hold  Ctrl + Option + Cmd\(ANSI.reset)\(ANSI.dim)  (simultaneously)\(ANSI.reset)

    \(ANSI.dim)  ──────────────────────────────────────────────────\(ANSI.reset)
    """)
}

func printAwake() {
    clearScreen()
    printBanner()
    print("""

    \(ANSI.green)\(ANSI.bold)  ✅  Keyboard is awake! You're good to go.\(ANSI.reset)

    \(ANSI.dim)  Thanks for using KeyboardHibernate.
      Run \(ANSI.reset)\(ANSI.cyan)kh\(ANSI.dim) anytime you want to clean again.\(ANSI.reset)

    """)
}

// MARK: - App Entry Point
func runApp() {
    if !AXIsProcessTrusted() {
        clearScreen()
        printBanner()
        print("""

    \(ANSI.yellow)\(ANSI.bold)  ⚠️  Accessibility Permission Required\(ANSI.reset)

    \(ANSI.white)  kh needs Accessibility access to hibernate the keyboard.\(ANSI.reset)

    \(ANSI.dim)  A system dialog has been shown — please:
      1. Open System Settings → Privacy & Security → Accessibility
      2. Enable your Terminal (or iTerm2, Warp, etc.) in the list
      3. Run \(ANSI.reset)\(ANSI.cyan)kh\(ANSI.dim) again\(ANSI.reset)

    """)
        _ = checkAccessibilityPermission()
        exit(1)
    }

    print(ANSI.hideCursor, terminator: "")
    clearScreen()
    printBanner()

    print("""

    \(ANSI.white)  Preparing to hibernate your keyboard for cleaning...\(ANSI.reset)
    \(ANSI.dim)  Press \(ANSI.reset)\(ANSI.red)Ctrl+C\(ANSI.dim) to cancel before the countdown ends.\(ANSI.reset)

    """)

    for i in stride(from: 10, through: 1, by: -1) {
        printCountdown(i)
        Thread.sleep(forTimeInterval: 1.0)
    }
    print()

    let hibernator = KeyboardHibernator()

    hibernator.onUnlockTriggered = {
        hibernator.stopHibernating()
        DispatchQueue.global().async {
            printAwake()
            playUnlockSound()
            sendNotification(
                title: "KeyboardHibernate",
                message: "⌨️ Keyboard is awake — ready to use!"
            )
            print(ANSI.showCursor, terminator: "")
            fflush(stdout)
            Thread.sleep(forTimeInterval: 1.5)
            exit(0)
        }
    }

    guard hibernator.startHibernating() else {
        print("""

    \(ANSI.red)  ✗ Failed to create keyboard event tap.\(ANSI.reset)
    \(ANSI.dim)  Make sure Accessibility permission is granted and try again.\(ANSI.reset)

    """)
        print(ANSI.showCursor, terminator: "")
        exit(1)
    }

    printHibernating()
    playLockSound()
    sendNotification(
        title: "KeyboardHibernate",
        message: "❄️ Keyboard hibernating — safe to clean! Hold ⌃⌥⌘ to wake."
    )

    RunLoop.main.run()
}

signal(SIGINT) { _ in
    print("\n\n\(ANSI.showCursor)\(ANSI.yellow)  Cancelled — keyboard was not hibernated.\(ANSI.reset)\n")
    exit(0)
}

runApp()
