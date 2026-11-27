import Foundation
import Darwin

public final class AppRunner {
    private let signalQueue = DispatchQueue(label: "com.shovon.kh.signals")
    private var signalSources: [DispatchSourceSignal] = []
    private var countdownTimer: DispatchSourceTimer?
    private var timeoutTimer: DispatchSourceTimer?
    private var hibernator: KeyboardHibernator?
    private var totalTimeout: Int?
    private var remainingTimeout: Int?
    private var currentHoldProgress: Double = 0.0
    private var didFinish = false

    public init() {}

    public func run(arguments: [String] = Array(CommandLine.arguments.dropFirst())) -> Int32 {
        var config: AppConfig
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

        switch config.command {
        case .update(let checkOnly, let quiet, let force):
            return runUpdateCommand(checkOnly: checkOnly, quiet: quiet, force: force, ui: ui)
        case .autoUpdate(let action):
            return runAutoUpdateCommand(action: action, ui: ui)
        case .run:
            break
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

        // Kick off throttled background auto-update check without delaying startup
        Updater.triggerBackgroundAutoCheckIfDue()
        let pendingUpdateNotice = Updater.consumeUpdateNotice()

        // Interactive duration prompt when running `kh` with no explicit timing flags
        if !config.hasExplicitTimingFlags && ui.isInteractiveInput {
            let defaultMouseLock = config.lockMouseExplicitlySet ? config.lockMouse : true
            guard let selection = ui.promptInteractiveSession(
                defaultLockMouse: defaultMouseLock,
                updateNotice: pendingUpdateNotice
            ) else {
                return 0
            }
            config.countdownSeconds = 0
            config.timeoutSeconds = selection.timeoutSeconds
            config.lockMouse = selection.lockMouse
        } else if let notice = pendingUpdateNotice, ui.isTTY {
            ui.printUpdateNotice(notice)
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

    // MARK: - Update & Auto-Update Subcommands

    private func runUpdateCommand(checkOnly: Bool, quiet: Bool, force: Bool, ui: TerminalUI) -> Int32 {
        do {
            if checkOnly {
                let status = try Updater.checkForUpdate()
                switch status {
                case .upToDate(let version, _):
                    if !quiet { ui.printSuccess("kh is already up to date (v\(version)).") }
                case .updateAvailable(let currentVersion, _, let remote):
                    if !quiet {
                        let short = remote.shortSha ?? String(remote.sha.prefix(7))
                        ui.printInfo("Update available: v\(currentVersion) → v\(remote.version) (\(short)). Run 'kh update' to install.")
                    }
                case .updated:
                    break
                }
                return 0
            }

            if !quiet {
                ui.printInfo("Checking GitHub Releases for updates...")
            }

            let status = try Updater.performUpdate(force: force, allowSudo: !quiet)
            switch status {
            case .upToDate(let version, _):
                if !quiet { ui.printSuccess("kh is already up to date (v\(version)).") }
            case .updated(let fromVersion, let toVersion, let sha):
                if !quiet {
                    let short = sha.map { " (\(String($0.prefix(7))))" } ?? ""
                    ui.printSuccess("Updated kh: v\(fromVersion) → v\(toVersion)\(short)")
                }
            case .updateAvailable:
                break
            }
            return 0
        } catch {
            if !quiet {
                ui.printError("\(error)")
            }
            return 1
        }
    }

    private func runAutoUpdateCommand(action: AutoUpdateAction, ui: TerminalUI) -> Int32 {
        switch action {
        case .enable:
            do {
                try Updater.enableAutoUpdateAgent()
                ui.printSuccess("Background auto-updater enabled (runs at login & every 6h).")
                ui.printInfo("LaunchAgent: \(Updater.launchAgentURL.path)")
                return 0
            } catch {
                ui.printError("\(error)")
                return 1
            }

        case .disable:
            Updater.disableAutoUpdateAgent()
            ui.printSuccess("Background auto-updater disabled and LaunchAgent removed.")
            return 0

        case .status:
            let enabled = Updater.isAutoUpdateAgentEnabled()
            let state = Updater.loadState()
            let binPath = Updater.currentExecutablePath()
            ui.printInfo("Binary:      \(binPath)")
            ui.printInfo("Version:     v\(AppMeta.version)\(state.installedSha.map { " (\($0.prefix(7)))" } ?? "")")
            ui.printInfo("LaunchAgent: \(enabled ? "Enabled (\(Updater.launchAgentURL.path))" : "Disabled")")
            if let last = state.lastCheckedEpoch {
                let date = Date(timeIntervalSince1970: last)
                let formatted = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
                ui.printInfo("Last check:  \(formatted)")
            } else {
                ui.printInfo("Last check:  Never")
            }
            return 0
        }
    }

    // MARK: - Signals & Cleanup

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
            let source = DispatchSource.makeSignalSource(signal: sig, queue: signalQueue)
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
        if wasHibernating {
            DispatchQueue.main.async { [weak self] in
                self?.hibernator?.stopHibernating()
                ui.showCursor()
                ui.printAwake(reason: .interrupted)
                exit(0)
            }
        } else {
            let restore = "\u{001B}[?25h\n\n  \(ui.palette.yellow)✕ Cancelled — input was not hibernated.\(ui.palette.reset)\n\n"
            _ = restore.withCString { ptr in
                write(STDOUT_FILENO, ptr, strlen(ptr))
            }
            _exit(0)
        }
    }

    // MARK: - Countdown & Hibernation

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
        totalTimeout = config.timeoutSeconds
        remainingTimeout = config.timeoutSeconds

        instance.onWakeHoldProgress = { [weak self] progress in
            guard let self = self, !self.didFinish else { return }
            self.currentHoldProgress = progress
            ui.updateLiveStatusLine(
                holdProgress: progress,
                remainingTimeout: self.remainingTimeout,
                totalTimeout: self.totalTimeout
            )
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

        let notifBody: String
        if let t = config.timeoutSeconds {
            notifBody = "❄️ Input hibernating for \(DurationHelper.formatHuman(t)) — hold ⌃⌥⌘ to wake early."
        } else {
            notifBody = "❄️ Input hibernating — safe to clean! Hold ⌃⌥⌘ to wake."
        }
        Feedback.sendNotification(title: AppMeta.name, message: notifBody, silent: config.silent)

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
                    ui.updateLiveStatusLine(
                        holdProgress: 0.0,
                        remainingTimeout: next,
                        totalTimeout: totalTimeout
                    )
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
            message: "⌨️ Input is awake — ready to use!",
            silent: false
        ) {
            group.leave()
        }

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
