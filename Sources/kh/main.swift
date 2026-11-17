import Foundation
import CoreGraphics
import AppKit

// MARK: - App Metadata
struct AppMeta {
    static let name    = "KeyboardHibernate"
    static let command = "kh"
    static let version = "1.1.0"
}

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
}

// MARK: - CLI Configuration & Argument Parsing
struct AppConfig {
    var countdownSeconds: Int = 10
    var silent: Bool = false
    var showHelp: Bool = false
    var showVersion: Bool = false
}

func parseArguments() -> AppConfig {
    var config = AppConfig()
    let args = Array(CommandLine.arguments.dropFirst())
    var i = 0

    while i < args.count {
        let arg = args[i]
        switch arg {
        case "-h", "--help":
            config.showHelp = true
        case "-v", "--version":
            config.showVersion = true
        case "--now":
            config.countdownSeconds = 0
        case "--silent":
            config.silent = true
        case "-s", "--seconds":
            i += 1
            if i < args.count, let sec = Int(args[i]), sec >= 0 {
                config.countdownSeconds = min(sec, 300)
            } else {
                fputs("\(ANSI.red)Error: --seconds requires a non-negative integer (0–300).\(ANSI.reset)\n", stderr)
                exit(1)
            }
        default:
            fputs("\(ANSI.red)Error: Unknown argument '\(arg)'.\(ANSI.reset)\n", stderr)
            fputs("Run '\(ANSI.cyan)\(AppMeta.command) --help\(ANSI.reset)' for usage.\n", stderr)
            exit(1)
        }
        i += 1
    }

    return config
}

func printHelp() {
    print("""
    \(ANSI.cyan)\(ANSI.bold)❄️  \(AppMeta.name) (\(AppMeta.command)) v\(AppMeta.version)\(ANSI.reset)
    \(ANSI.dim)A zero-dependency macOS CLI utility to safely hibernate your keyboard for cleaning.\(ANSI.reset)

    \(ANSI.bold)USAGE:\(ANSI.reset)
      \(ANSI.cyan)\(AppMeta.command)\(ANSI.reset) [options]

    \(ANSI.bold)OPTIONS:\(ANSI.reset)
      \(ANSI.yellow)-s, --seconds <sec>\(ANSI.reset)   Countdown before hibernation (default: 10, max: 300)
      \(ANSI.yellow)    --now\(ANSI.reset)             Hibernate immediately without countdown
      \(ANSI.yellow)    --silent\(ANSI.reset)          Disable sound feedback and notifications
      \(ANSI.yellow)-v, --version\(ANSI.reset)         Show version information
      \(ANSI.yellow)-h, --help\(ANSI.reset)            Show this help screen

    \(ANSI.bold)WAKE SHORTCUT:\(ANSI.reset)
      Hold \(ANSI.bold)Ctrl + Option + Cmd\(ANSI.reset) simultaneously to wake up.
      \(ANSI.dim)(Every regular key including Space remains 100% blocked while hibernating)\(ANSI.reset)

    \(ANSI.bold)PERMISSIONS:\(ANSI.reset)
      Requires Accessibility permissions:
      \(ANSI.dim)System Settings → Privacy & Security → Accessibility → enable your Terminal.\(ANSI.reset)
    """)
}

func printVersion() {
    print("\(AppMeta.command) \(AppMeta.version)")
}

// MARK: - Sound Feedback (Non-blocking)
func playSound(named names: [String], silent: Bool) {
    guard !silent else { return }
    DispatchQueue.global(qos: .userInitiated).async {
        for name in names {
            if let sound = NSSound(named: NSSound.Name(name)) {
                sound.volume = 0.4
                sound.play()
                return
            }
        }
        NSSound.beep()
    }
}

func playLockSound(silent: Bool) {
    playSound(named: ["Funk", "Pop", "Tink", "Morse"], silent: silent)
}

func playUnlockSound(silent: Bool) {
    playSound(named: ["Glass", "Hero", "Ping", "Purr"], silent: silent)
}

// MARK: - macOS Native Notification (Non-blocking)
func sendNotification(title: String, message: String, silent: Bool) {
    guard !silent else { return }
    DispatchQueue.global(qos: .background).async {
        let escapedMessage = message.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedTitle   = title.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "display notification \"\(escapedMessage)\" with title \"\(escapedTitle)\""

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
    }
}

// MARK: - Accessibility Permission
func checkAccessibilityPermission() -> Bool {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
    return AXIsProcessTrustedWithOptions(options)
}

// MARK: - Keyboard Hibernator
class KeyboardHibernator {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var selfPtr: UnsafeMutableRawPointer?
    private(set) var isHibernating = false
    private var isUnlocking = false

    var onUnlockTriggered: (() -> Void)?

    private let callback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon = refcon else {
            return Unmanaged.passRetained(event)
        }
        let hibernator = Unmanaged<KeyboardHibernator>.fromOpaque(refcon).takeUnretainedValue()

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS disabled the event tap under system pressure — re-enable immediately
            if let tap = hibernator.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return nil

        case .flagsChanged:
            let flags = event.flags
            let hasCtrl = flags.contains(.maskControl)
            let hasAlt  = flags.contains(.maskAlternate)
            let hasCmd  = flags.contains(.maskCommand)

            if hasCtrl && hasAlt && hasCmd {
                if !hibernator.isUnlocking {
                    hibernator.isUnlocking = true
                    DispatchQueue.main.async {
                        hibernator.onUnlockTriggered?()
                    }
                }
            }
            // Block modifier changes so they never leak through
            return nil

        case .keyDown, .keyUp:
            // Block every single key event
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

        let ptr = Unmanaged.passRetained(self).toOpaque()
        self.selfPtr = ptr

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: ptr
        ) else {
            Unmanaged<KeyboardHibernator>.fromOpaque(ptr).release()
            self.selfPtr = nil
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

    func stopHibernating() {
        guard isHibernating else { return }
        isHibernating = false

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil

        if let ptr = selfPtr {
            Unmanaged<KeyboardHibernator>.fromOpaque(ptr).release()
            selfPtr = nil
        }
    }

    deinit {
        stopHibernating()
    }
}

// MARK: - UI & Terminal Display
func clearScreen() {
    print("\u{001B}[2J\u{001B}[H", terminator: "")
}

func printBanner() {
    let banner = """
    \(ANSI.cyan)\(ANSI.bold)╔═══════════════════════════════════════════╗
    ║        ❄️   \(AppMeta.name)   ❄️         ║
    ║          \(ANSI.dim)github.com/shovon05/kh\(ANSI.reset)\(ANSI.cyan)\(ANSI.bold)            ║
    ╚═══════════════════════════════════════════╝\(ANSI.reset)
    """
    print(banner)
}

func buildProgressBar(current: Int, total: Int, width: Int) -> String {
    guard total > 0 else { return "" }
    let ratio = min(max(Double(current) / Double(total), 0.0), 1.0)
    let filled = Int(ratio * Double(width))
    let empty  = width - filled
    let filledStr = String(repeating: "█", count: max(0, filled))
    let emptyStr  = String(repeating: "░", count: max(0, empty))
    return "\(ANSI.cyan)[\(filledStr)\(ANSI.dim)\(emptyStr)\(ANSI.reset)\(ANSI.cyan)]\(ANSI.reset)"
}

func printCountdown(_ seconds: Int, total: Int) {
    let bar = buildProgressBar(current: total - seconds, total: total, width: 30)
    let color = seconds > (total / 2) ? ANSI.yellow : ANSI.red
    print("\(ANSI.clearLine)\(ANSI.bold)  \(color)⏱  Hibernating keyboard in  \(ANSI.white)\(seconds)s\(ANSI.reset)  \(bar)", terminator: "")
    fflush(stdout)
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

    \(ANSI.dim)  Thanks for using \(AppMeta.name).
      Run \(ANSI.reset)\(ANSI.cyan)\(AppMeta.command)\(ANSI.dim) anytime you want to clean again.\(ANSI.reset)

    """)
}

// MARK: - Safe Signal & Terminal Cleanup Setup
func setupTerminalCleanup() {
    // atexit ensures cursor restoration regardless of exit path
    atexit {
        let restore = ANSI.showCursor
        _ = restore.utf8CString.withUnsafeBufferPointer { ptr in
            write(STDOUT_FILENO, ptr.baseAddress, ptr.count - 1)
        }
    }

    let signals = [SIGINT, SIGTERM, SIGHUP]
    for sig in signals {
        signal(sig) { _ in
            let msg = "\n\n\u{001B}[?25h\u{001B}[33m  Cancelled — keyboard was not hibernated.\u{001B}[0m\n\n"
            _ = msg.utf8CString.withUnsafeBufferPointer { ptr in
                write(STDOUT_FILENO, ptr.baseAddress, ptr.count - 1)
            }
            exit(0)
        }
    }
}

// MARK: - Application Lifecycle
func runApp() {
    let config = parseArguments()

    if config.showHelp {
        printHelp()
        exit(0)
    }

    if config.showVersion {
        printVersion()
        exit(0)
    }

    setupTerminalCleanup()

    // Verify Accessibility Permissions
    if !AXIsProcessTrusted() {
        clearScreen()
        printBanner()
        print("""

    \(ANSI.yellow)\(ANSI.bold)  ⚠️  Accessibility Permission Required\(ANSI.reset)

    \(ANSI.white)  \(AppMeta.command) needs Accessibility access to hibernate the keyboard.\(ANSI.reset)

    \(ANSI.dim)  A system prompt has been requested — please:
      1. Open System Settings → Privacy & Security → Accessibility
      2. Enable your Terminal (or iTerm2, Warp, Ghostty, etc.)
      3. Run \(ANSI.reset)\(ANSI.cyan)\(AppMeta.command)\(ANSI.dim) again\(ANSI.reset)

    """)
        _ = checkAccessibilityPermission()
        exit(1)
    }

    print(ANSI.hideCursor, terminator: "")
    fflush(stdout)

    // Countdown phase (if seconds > 0)
    if config.countdownSeconds > 0 {
        clearScreen()
        printBanner()
        print("""

    \(ANSI.white)  Preparing to hibernate your keyboard for cleaning...\(ANSI.reset)
    \(ANSI.dim)  Press \(ANSI.reset)\(ANSI.red)Ctrl+C\(ANSI.dim) to cancel before the countdown ends.\(ANSI.reset)

    """)

        for i in stride(from: config.countdownSeconds, through: 1, by: -1) {
            printCountdown(i, total: config.countdownSeconds)
            Thread.sleep(forTimeInterval: 1.0)
        }
        print()
    }

    let hibernator = KeyboardHibernator()

    hibernator.onUnlockTriggered = {
        hibernator.stopHibernating()
        printAwake()
        playUnlockSound(silent: config.silent)
        sendNotification(
            title: AppMeta.name,
            message: "⌨️ Keyboard is awake — ready to use!",
            silent: config.silent
        )
        print(ANSI.showCursor, terminator: "")
        fflush(stdout)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            exit(0)
        }
    }

    guard hibernator.startHibernating() else {
        print("""

    \(ANSI.red)  ✗ Failed to create keyboard event tap.\(ANSI.reset)
    \(ANSI.dim)  Make sure Accessibility permission is enabled for your Terminal.\(ANSI.reset)

    """)
        exit(1)
    }

    printHibernating()
    playLockSound(silent: config.silent)
    sendNotification(
        title: AppMeta.name,
        message: "❄️ Keyboard hibernating — safe to clean! Hold ⌃⌥⌘ to wake.",
        silent: config.silent
    )

    RunLoop.main.run()
}

runApp()
