import Foundation
import Darwin

public final class AppRunner {
    private var signalSources: [DispatchSourceSignal] = []
    private var countdownTimer: DispatchSourceTimer?
    private var timeoutTimer: DispatchSourceTimer?
    private var hibernator: KeyboardHibernator?
    private var remainingTimeout: Int?
    private var currentHoldProgress: Double = 0.0
    private var didFinish = false

    public init() {}

    public func run(arguments: [String] = Array(CommandLine.arguments.dropFirst())) -> Int32 {
        let config: AppConfig
        do {
            config = try CLIParser.parse(arguments)
        } catch {
            let ui = TerminalUI()
            ui.printError("\(error)", hint: "Run '\(AppMeta.command) --help' for usage.")
            return 1
        }

        let ui = TerminalUI(noColor: config.noColor)

        if config.showHelp {
            ui.printHelp()
            return 0
        }

        if config.showVersion {
            ui.printVersion()
            return 0
        }

        installCursorRestoreAtExit()
        installSignalSources(ui: ui)

        if !AccessibilityHelper.isTrusted(promptIfNeeded: false) {
            ui.printAccessibilityInstructions()
            _ = AccessibilityHelper.isTrusted(promptIfNeeded: true)
            return 1
        }

        if AccessibilityHelper.isSecureEventInputEnabled() {
            ui.printWarning("Secure Keyboard Entry is active (e.g. Terminal menu or password field). macOS may block event interception until disabled.")
        }

        ui.hideCursor()

        if config.countdownSeconds > 0 {
            startCountdown(seconds: config.countdownSeconds, config: config, ui: ui)
        } else {
            beginHibernation(config: config, ui: ui)
        }

        RunLoop.main.run()
        return 0
    }

    private func installCursorRestoreAtExit() {
        atexit {
            let restore = "\u{001B}[?25h"
            _ = restore.withCString { ptr in
                write(STDOUT_FILENO, ptr, strlen(ptr))
            }
        }
    }

    private func installSignalSources(ui: TerminalUI) {
        let signals: [Int32] = [SIGINT, SIGTERM, SIGHUP]
        for sig in signals {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in
                self?.handleTerminationSignal(ui: ui)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private func handleTerminationSignal(ui: TerminalUI) {
        guard !didFinish else { return }
        didFinish = true

        countdownTimer?.cancel()
        countdownTimer = nil
        timeoutTimer?.cancel()
        timeoutTimer = nil

        let wasHibernating = hibernator?.isHibernating ?? false
        hibernator?.stopHibernating()
        ui.showCursor()

        if wasHibernating {
            ui.printAwake(reason: .interrupted)
        } else {
            let p = ui.palette
            print("\n\n  \(p.yellow)✕ Cancelled — keyboard was not hibernated.\(p.reset)\n")
            fflush(stdout)
        }
        exit(0)
    }

    private func startCountdown(seconds: Int, config: AppConfig, ui: TerminalUI) {
        ui.printCountdownHeader(config: config)
        var remaining = seconds
        ui.updateCountdown(remaining: remaining, total: seconds)

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            guard let self = self, !self.didFinish else { return }
            remaining -= 1
            if remaining > 0 {
                ui.updateCountdown(remaining: remaining, total: seconds)
            } else {
                self.countdownTimer?.cancel()
                self.countdownTimer = nil
                if ui.isTTY {
                    print()
                }
                self.beginHibernation(config: config, ui: ui)
            }
        }
        countdownTimer = timer
        timer.resume()
    }

    private func beginHibernation(config: AppConfig, ui: TerminalUI) {
        let instance = KeyboardHibernator(lockMouse: config.lockMouse)
        hibernator = instance
        remainingTimeout = config.timeoutSeconds

        instance.onWakeHoldProgress = { [weak self] progress in
            guard let self = self, !self.didFinish else { return }
            self.currentHoldProgress = progress
            ui.updateWakeStatusLine(holdProgress: progress, remainingTimeout: self.remainingTimeout)
        }

        instance.onUnlockTriggered = { [weak self] reason in
            self?.finishHibernation(reason: reason, config: config, ui: ui)
        }

        guard instance.startHibernating() else {
            ui.showCursor()
            ui.printError(
                "Failed to create keyboard event tap.",
                hint: "Verify Accessibility permission is enabled for your Terminal."
            )
            exit(1)
        }

        ui.printHibernating(config: config)
        Feedback.playLockSound(silent: config.silent)
        Feedback.sendNotification(
            title: AppMeta.name,
            message: "❄️ Input hibernating — safe to clean! Hold ⌃⌥⌘ to wake.",
            silent: config.silent
        )

        if let timeout = config.timeoutSeconds {
            startAutoWakeTimer(totalTimeout: timeout, config: config, ui: ui)
        }
    }

    private func startAutoWakeTimer(totalTimeout: Int, config: AppConfig, ui: TerminalUI) {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            guard let self = self, !self.didFinish else { return }
            guard let current = self.remainingTimeout else { return }
            let next = current - 1
            self.remainingTimeout = next

            if next > 0 {
                if self.currentHoldProgress <= 0.0 {
                    ui.updateWakeStatusLine(holdProgress: 0.0, remainingTimeout: next)
                }
            } else {
                self.finishHibernation(reason: .timeout(seconds: totalTimeout), config: config, ui: ui)
            }
        }
        timeoutTimer = timer
        timer.resume()
    }

    private func finishHibernation(reason: WakeReason, config: AppConfig, ui: TerminalUI) {
        guard !didFinish else { return }
        didFinish = true

        timeoutTimer?.cancel()
        timeoutTimer = nil
        hibernator?.stopHibernating()
        hibernator = nil

        ui.printAwake(reason: reason)
        ui.showCursor()

        if config.silent {
            exit(0)
        }

        Feedback.playUnlockSound(silent: false)

        let group = DispatchGroup()
        group.enter()
        Feedback.sendNotification(
            title: AppMeta.name,
            message: "⌨️ Keyboard is awake — ready to use!",
            silent: false
        ) {
            group.leave()
        }

        // Allow sound playback (~0.6s) and notification dispatch, bounded at 1.5s
        var didExit = false
        let exitSafely = {
            guard !didExit else { return }
            didExit = true
            exit(0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            group.notify(queue: .main) {
                exitSafely()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            exitSafely()
        }
    }
}
