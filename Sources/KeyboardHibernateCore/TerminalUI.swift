import Foundation
import Darwin

public struct TerminalPalette {
    public let isEnabled: Bool

    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    public var reset: String { isEnabled ? "\u{001B}[0m" : "" }
    public var bold: String { isEnabled ? "\u{001B}[1m" : "" }
    public var dim: String { isEnabled ? "\u{001B}[2m" : "" }
    public var red: String { isEnabled ? "\u{001B}[31m" : "" }
    public var green: String { isEnabled ? "\u{001B}[32m" : "" }
    public var yellow: String { isEnabled ? "\u{001B}[33m" : "" }
    public var cyan: String { isEnabled ? "\u{001B}[36m" : "" }
    public var brightCyan: String { isEnabled ? "\u{001B}[96m" : "" }
    public var white: String { isEnabled ? "\u{001B}[97m" : "" }
    public var clearLine: String { isEnabled ? "\u{001B}[2K\r" : "" }
    public var clearScreen: String { isEnabled ? "\u{001B}[2J\u{001B}[H" : "" }
    public var hideCursor: String { isEnabled ? "\u{001B}[?25l" : "" }
    public var showCursor: String { isEnabled ? "\u{001B}[?25h" : "" }
}

public enum WakeReason: Equatable {
    case wakeChord
    case timeout(seconds: Int)
    case systemDisabled
    case interrupted
}

public struct InteractiveSelection: Equatable {
    public let timeoutSeconds: Int?
    public let lockMouse: Bool
}

public final class TerminalUI {
    public let isTTY: Bool
    public let isInteractiveInput: Bool
    public let palette: TerminalPalette
    private let cardInnerWidth: Int

    public init(
        noColor: Bool = false,
        isTTY: Bool? = nil,
        isInteractiveInput: Bool? = nil,
        terminalColumns: Int? = nil
    ) {
        let detectedTTY = isTTY ?? (isatty(STDOUT_FILENO) != 0)
        self.isTTY = detectedTTY
        self.isInteractiveInput = isInteractiveInput ?? (detectedTTY && isatty(STDIN_FILENO) != 0)

        let envNoColor = ProcessInfo.processInfo.environment["NO_COLOR"] != nil
        let colorEnabled = detectedTTY && !noColor && !envNoColor
        self.palette = TerminalPalette(isEnabled: colorEnabled)

        let cols = terminalColumns ?? Self.detectTerminalColumns()
        self.cardInnerWidth = max(46, min(58, cols - 6))
    }

    private static func detectTerminalColumns() -> Int {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0, ws.ws_col > 0 {
            return Int(ws.ws_col)
        }
        return 80
    }

    public static func stripANSI(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var i = text.startIndex
        while i < text.endIndex {
            if text[i] == "\u{001B}" {
                let next = text.index(after: i)
                if next < text.endIndex, text[next] == "[" {
                    var j = text.index(after: next)
                    while j < text.endIndex {
                        let ch = text[j]
                        j = text.index(after: j)
                        if ("@"..."~").contains(ch) {
                            break
                        }
                    }
                    i = j
                    continue
                }
            }
            result.append(text[i])
            i = text.index(after: i)
        }
        return result
    }

    public static func displayWidth(_ text: String) -> Int {
        stripANSI(text).count
    }

    public static func padRight(_ text: String, toWidth width: Int) -> String {
        let visible = displayWidth(text)
        guard visible < width else { return text }
        return text + String(repeating: " ", count: width - visible)
    }

    public func buildProgressBar(ratio: Double, width: Int = 24, filledColor: String? = nil) -> String {
        let clamped = min(max(ratio, 0.0), 1.0)
        let filledCount = Int((clamped * Double(width)).rounded(.toNearestOrAwayFromZero))
        let safeFilled = min(max(0, filledCount), width)
        let emptyCount = width - safeFilled

        let fill = filledColor ?? palette.brightCyan
        let filledStr = String(repeating: "█", count: safeFilled)
        let emptyStr = String(repeating: "░", count: emptyCount)
        return "\(palette.dim)[\(palette.reset)\(fill)\(filledStr)\(palette.dim)\(emptyStr)]\(palette.reset)"
    }

    public func renderCard(lines: [String], borderColor: String? = nil) -> String {
        let border = borderColor ?? palette.cyan
        let contentWidth = max(cardInnerWidth, lines.map(Self.displayWidth).max() ?? 0)
        let horizontal = String(repeating: "─", count: contentWidth + 2)

        var out: [String] = []
        out.append("  \(border)╭\(horizontal)╮\(palette.reset)")
        for line in lines {
            let padded = Self.padRight(line, toWidth: contentWidth)
            out.append("  \(border)│\(palette.reset) \(padded) \(border)│\(palette.reset)")
        }
        out.append("  \(border)╰\(horizontal)╯\(palette.reset)")
        return out.joined(separator: "\n")
    }

    public func printHelp() {
        let p = palette
        print("""
        \(p.brightCyan)\(p.bold)◈ \(AppMeta.name) (\(AppMeta.command)) v\(AppMeta.version)\(p.reset)
        \(p.dim)Zero-dependency macOS utility that locks your keyboard & mouse/trackpad for cleaning.\(p.reset)

        \(p.bold)USAGE\(p.reset)
          \(p.cyan)\(AppMeta.command)\(p.reset)                         Interactive duration prompt + lock keyboard & mouse
          \(p.cyan)\(AppMeta.command)\(p.reset) [options]               Run directly with CLI flags
          \(p.cyan)\(AppMeta.command) update\(p.reset) [--check]        Update binary from latest GitHub Release
          \(p.cyan)\(AppMeta.command) auto-update\(p.reset) <action>   Manage background LaunchAgent (enable|disable|status)

        \(p.bold)OPTIONS\(p.reset)
          \(p.yellow)-s, --seconds <sec>\(p.reset)   Countdown before hibernation (0–\(AppMeta.maxCountdownSeconds), default: 10)
          \(p.yellow)    --now\(p.reset)             Hibernate immediately without a countdown
          \(p.yellow)-t, --timeout <dur>\(p.reset)   Hibernate duration (e.g. 500, 90s, 5m, 2m30s; max \(AppMeta.maxTimeoutSeconds)s)
          \(p.yellow)-m, --lock-mouse\(p.reset)      Also lock mouse/trackpad clicks, movement, and scrolling
          \(p.yellow)    --no-lock-mouse\(p.reset)   Lock keyboard only (in interactive mode)
          \(p.yellow)    --silent\(p.reset)          Disable chime sounds and desktop notifications
          \(p.yellow)    --no-color\(p.reset)        Disable ANSI colors (also respects NO_COLOR)
          \(p.yellow)-v, --version\(p.reset)         Show version information
          \(p.yellow)-h, --help\(p.reset)            Show this help screen

        \(p.bold)WAKE SHORTCUT\(p.reset)
          Hold \(p.bold)Ctrl + Option + Cmd\(p.reset) together for \(String(format: "%.1fs", AppMeta.wakeHoldDuration)) to wake early.
          \(p.dim)(Brief hold prevents accidental unlocks when wiping bottom-left keys.)\(p.reset)

        \(p.bold)PERMISSIONS & NOTES\(p.reset)
          \(p.dim)• Enable your terminal in: System Settings → Privacy & Security → Accessibility\(p.reset)
          \(p.dim)• Disable "Secure Keyboard Entry" in Terminal if key interception is blocked.\(p.reset)
          \(p.dim)• Hardware Power / Touch ID remains handled by macOS.\(p.reset)
        """)
    }

    public func printVersion() {
        print("\(AppMeta.command) \(AppMeta.version)")
    }

    public func hideCursor() {
        guard isTTY else { return }
        print(palette.hideCursor, terminator: "")
        fflush(stdout)
    }

    public func showCursor() {
        guard isTTY else { return }
        print(palette.showCursor, terminator: "")
        fflush(stdout)
    }

    public func printBanner() {
        let p = palette
        let card = renderCard(
            lines: [
                "\(p.brightCyan)\(p.bold)◈ \(AppMeta.name)\(p.reset)  \(p.dim)v\(AppMeta.version)\(p.reset)",
                "\(p.dim)\(AppMeta.repoURL)\(p.reset)"
            ],
            borderColor: p.cyan
        )
        print("\n\(card)")
    }

    public func printUpdateNotice(_ notice: String) {
        let p = palette
        print("\n  \(p.green)↑\(p.reset) \(p.dim)\(notice)\(p.reset)")
    }

    // MARK: - Interactive Wizard

    public func promptInteractiveSession(defaultLockMouse: Bool, updateNotice: String? = nil) -> InteractiveSelection? {
        let p = palette
        if isTTY {
            print(p.clearScreen, terminator: "")
        }
        printBanner()
        if let notice = updateNotice {
            printUpdateNotice(notice)
        }

        print("")
        print("  \(p.white)\(p.bold)How long do you want to hibernate?\(p.reset)")
        print("")
        print("    \(p.cyan)[1]\(p.reset)  1 min    \(p.dim)(60 sec)\(p.reset)")
        print("    \(p.cyan)[2]\(p.reset)  2 min    \(p.dim)(120 sec)\(p.reset)")
        print("    \(p.cyan)[3]\(p.reset)  5 min    \(p.dim)(300 sec)\(p.reset)")
        print("    \(p.cyan)[4]\(p.reset)  Custom   \(p.dim)(e.g. 500, 90s, 5m, 2m30s)\(p.reset)")
        print("    \(p.cyan)[5]\(p.reset)  No timer \(p.dim)(stay locked until ⌃ ⌥ ⌘ wake)\(p.reset)")
        print("")

        var chosenTimeout: Int?
        var resolved = false

        while !resolved {
            print("  \(p.yellow)Select [1–5] or enter duration\(p.reset) \(p.dim)(default 1):\(p.reset) ", terminator: "")
            fflush(stdout)

            guard let raw = readLine() else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty || trimmed == "1" {
                chosenTimeout = 60
                resolved = true
            } else if trimmed == "2" {
                chosenTimeout = 120
                resolved = true
            } else if trimmed == "3" {
                chosenTimeout = 300
                resolved = true
            } else if trimmed == "5" {
                chosenTimeout = nil
                resolved = true
            } else if trimmed == "4" {
                guard let custom = promptCustomDuration() else { return nil }
                chosenTimeout = custom
                resolved = true
            } else {
                // Allow direct entry like "500" or "3m" or "2m30s"
                do {
                    chosenTimeout = try DurationHelper.parse(trimmed, minSeconds: 1, maxSeconds: AppMeta.maxTimeoutSeconds)
                    resolved = true
                } catch {
                    print("  \(p.red)✕ \(error)\(p.reset)")
                }
            }
        }

        // Show converted summary & confirm start
        print("")
        let durationLine: String
        if let seconds = chosenTimeout {
            let human = DurationHelper.formatHuman(seconds)
            if seconds >= 60 {
                durationLine = "\(p.brightCyan)\(p.bold)\(human)\(p.reset) \(p.dim)(\(seconds)s)\(p.reset)"
            } else {
                durationLine = "\(p.brightCyan)\(p.bold)\(human)\(p.reset)"
            }
        } else {
            durationLine = "\(p.brightCyan)\(p.bold)Unlimited\(p.reset) \(p.dim)(until ⌃ ⌥ ⌘ wake)\(p.reset)"
        }

        let lockScope = defaultLockMouse
            ? "\(p.white)Keyboard + Mouse & Trackpad\(p.reset)"
            : "\(p.white)Keyboard only\(p.reset)"

        let summary = renderCard(
            lines: [
                "\(p.dim)Duration:  \(p.reset)\(durationLine)",
                "\(p.dim)Locking:   \(p.reset)\(lockScope)",
                "\(p.dim)Wake:      \(p.reset)Hold \(p.bold)Ctrl + Option + Cmd\(p.reset) (\(String(format: "%.1fs", AppMeta.wakeHoldDuration)))"
            ],
            borderColor: p.cyan
        )
        print(summary)
        print("")
        print("  \(p.green)▸\(p.reset) \(p.bold)Press Enter to start hibernating\(p.reset) \(p.dim)(or Ctrl+C to cancel):\(p.reset) ", terminator: "")
        fflush(stdout)

        guard readLine() != nil else { return nil }
        return InteractiveSelection(timeoutSeconds: chosenTimeout, lockMouse: defaultLockMouse)
    }

    private func promptCustomDuration() -> Int? {
        let p = palette
        while true {
            print("  \(p.yellow)Enter duration\(p.reset) \(p.dim)(e.g. 500 for 500s, or 5m / 2m30s):\(p.reset) ", terminator: "")
            fflush(stdout)
            guard let raw = readLine() else { return nil }
            do {
                return try DurationHelper.parse(raw, minSeconds: 1, maxSeconds: AppMeta.maxTimeoutSeconds)
            } catch {
                print("  \(p.red)✕ \(error)\(p.reset)")
            }
        }
    }

    // MARK: - Countdown & Hibernation Screens

    public func printCountdownHeader(config: AppConfig) {
        let p = palette
        if isTTY {
            print(p.clearScreen, terminator: "")
        }
        printBanner()

        var badges: [String] = []
        if config.lockMouse { badges.append("Keyboard + Mouse Locked") }
        if let t = config.timeoutSeconds { badges.append("Timer: \(DurationHelper.formatHuman(t))") }
        if config.silent { badges.append("Silent") }

        print("")
        print("  \(p.white)Preparing to hibernate input for cleaning...\(p.reset)")
        if !badges.isEmpty {
            print("  \(p.dim)Mode: \(badges.joined(separator: "  •  "))\(p.reset)")
        }
        print("  \(p.dim)Press \(p.red)Ctrl+C\(p.reset)\(p.dim) anytime to cancel.\(p.reset)")
        print("")
        fflush(stdout)
    }

    public func updateCountdown(remaining: Int, total: Int) {
        let p = palette
        let progress = total > 0 ? Double(total - remaining) / Double(total) : 1.0
        let barColor = remaining <= 3 ? p.red : p.yellow
        let bar = buildProgressBar(ratio: progress, width: 24, filledColor: barColor)
        let pct = Int((progress * 100).rounded())

        if isTTY {
            print("\(p.clearLine)  \(barColor)●\(p.reset) Starting in \(p.bold)\(remaining)s\(p.reset)  \(bar)  \(p.dim)\(pct)%\(p.reset)", terminator: "")
            fflush(stdout)
        } else {
            print("Starting in \(remaining)s...")
        }
    }

    public func printHibernating(config: AppConfig) {
        let p = palette
        if isTTY {
            print(p.clearScreen, terminator: "")
        }
        printBanner()

        var rows = [
            "\(p.brightCyan)\(p.bold)● INPUT HIBERNATING — SAFE TO CLEAN\(p.reset)",
            "",
            "\(p.white)▸ Keys, modifiers, Space & media keys blocked\(p.reset)"
        ]
        if config.lockMouse {
            rows.append("\(p.white)▸ Mouse & trackpad clicks/movement blocked\(p.reset)")
        } else {
            rows.append("\(p.dim)▸ Mouse & trackpad active (use --lock-mouse to lock)\(p.reset)")
        }
        rows.append("")
        rows.append("\(p.yellow)Wake:\(p.reset) Hold \(p.bold)Ctrl + Option + Cmd\(p.reset) for \(String(format: "%.1fs", AppMeta.wakeHoldDuration))")
        if let timeout = config.timeoutSeconds {
            rows.append("\(p.dim)Timer: \(DurationHelper.formatHuman(timeout)) (\(DurationHelper.formatClock(timeout)))\(p.reset)")
        }

        print("")
        print(renderCard(lines: rows, borderColor: p.brightCyan))
        print("")
        updateLiveStatusLine(
            holdProgress: 0.0,
            remainingTimeout: config.timeoutSeconds,
            totalTimeout: config.timeoutSeconds
        )
    }

    public func updateLiveStatusLine(holdProgress: Double, remainingTimeout: Int?, totalTimeout: Int?) {
        let p = palette
        guard isTTY else {
            if holdProgress >= 1.0 {
                print("Wake chord triggered.")
            }
            return
        }

        let clampedHold = min(max(holdProgress, 0.0), 1.0)
        if clampedHold > 0.0 {
            let bar = buildProgressBar(ratio: clampedHold, width: 20, filledColor: p.green)
            let pct = Int((clampedHold * 100).rounded())
            print("\(p.clearLine)  \(p.green)▸\(p.reset) Waking: \(bar) \(p.bold)\(pct)%\(p.reset) \(p.dim)(keep holding ⌃ ⌥ ⌘)\(p.reset)", terminator: "")
            fflush(stdout)
            return
        }

        if let remaining = remainingTimeout, let total = totalTimeout, total > 0 {
            let elapsed = max(0, total - remaining)
            let ratio = Double(elapsed) / Double(total)
            let bar = buildProgressBar(ratio: ratio, width: 22, filledColor: p.brightCyan)
            let pct = Int((ratio * 100).rounded())
            let leftStr = DurationHelper.formatClock(remaining)
            let totalStr = DurationHelper.formatClock(total)
            print("\(p.clearLine)  \(p.brightCyan)▸\(p.reset) Timer:  \(bar) \(p.bold)\(pct)%\(p.reset)  \(p.dim)•\(p.reset)  \(p.white)\(leftStr)\(p.reset) \(p.dim)left (of \(totalStr))\(p.reset)", terminator: "")
        } else {
            let bar = buildProgressBar(ratio: 0.0, width: 20, filledColor: p.cyan)
            print("\(p.clearLine)  \(p.dim)▸\(p.reset) Wake:   \(bar) \(p.dim)Hold ⌃ ⌥ ⌘ to wake\(p.reset)", terminator: "")
        }
        fflush(stdout)
    }

    public func printAwake(reason: WakeReason) {
        let p = palette
        if isTTY {
            print(p.clearScreen, terminator: "")
        }
        printBanner()

        let reasonText: String
        switch reason {
        case .wakeChord:
            reasonText = "Unlocked with Ctrl + Option + Cmd."
        case .timeout(let seconds):
            reasonText = "Timer finished (\(DurationHelper.formatHuman(seconds))) — input restored."
        case .systemDisabled:
            reasonText = "Event tap was disabled by macOS; input restored."
        case .interrupted:
            reasonText = "Session interrupted; input restored."
        }

        let card = renderCard(
            lines: [
                "\(p.green)\(p.bold)✓ Input is awake — ready to use\(p.reset)",
                "\(p.dim)\(reasonText)\(p.reset)"
            ],
            borderColor: p.green
        )
        print("")
        print(card)
        print("")
        fflush(stdout)
    }

    public func printAccessibilityInstructions() {
        let p = palette
        if isTTY {
            print(p.clearScreen, terminator: "")
        }
        printBanner()

        let card = renderCard(
            lines: [
                "\(p.yellow)\(p.bold)! Accessibility Permission Required\(p.reset)",
                "",
                "\(p.white)\(AppMeta.command) needs Accessibility access to intercept input.\(p.reset)",
                "\(p.dim)1. Open System Settings → Privacy & Security → Accessibility\(p.reset)",
                "\(p.dim)2. Enable your Terminal app (Terminal, iTerm2, Ghostty, Warp)\(p.reset)",
                "\(p.dim)3. Run '\(AppMeta.command)' again\(p.reset)"
            ],
            borderColor: p.yellow
        )
        print("")
        print(card)
        print("")
    }

    public func printError(_ message: String, hint: String? = nil) {
        let p = palette
        fputs("\(p.red)✕ Error:\(p.reset) \(message)\n", stderr)
        if let hint = hint {
            fputs("  \(p.dim)\(hint)\(p.reset)\n", stderr)
        }
    }

    public func printWarning(_ message: String) {
        let p = palette
        fputs("\(p.yellow)! Warning:\(p.reset) \(message)\n", stderr)
    }

    public func printInfo(_ message: String) {
        let p = palette
        print("  \(p.cyan)▸\(p.reset) \(message)")
    }

    public func printSuccess(_ message: String) {
        let p = palette
        print("  \(p.green)✓\(p.reset) \(message)")
    }
}
