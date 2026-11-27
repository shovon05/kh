import Testing
import Foundation
import CoreGraphics
@testable import KeyboardHibernateCore

@Suite("KeyboardHibernateCore Tests")
struct KeyboardHibernateCoreTests {
    @Test("Default CLI config values")
    func defaultConfig() throws {
        let config = try CLIParser.parse([])
        #expect(config.command == .run)
        #expect(config.countdownSeconds == 10)
        #expect(config.timeoutSeconds == nil)
        #expect(config.lockMouse == false)
        #expect(config.hasExplicitTimingFlags == false)
        #expect(config.silent == false)
        #expect(config.noColor == false)
        #expect(config.showHelp == false)
        #expect(config.showVersion == false)
    }

    @Test("Valid long flags, duration strings, and inline = syntax")
    func validFlagsAndInlineEquals() throws {
        let config = try CLIParser.parse([
            "--seconds=5",
            "--timeout=5m",
            "--lock-mouse",
            "--silent",
            "--no-color"
        ])
        #expect(config.countdownSeconds == 5)
        #expect(config.timeoutSeconds == 300)
        #expect(config.lockMouse == true)
        #expect(config.lockMouseExplicitlySet == true)
        #expect(config.hasExplicitTimingFlags == true)
        #expect(config.silent == true)
        #expect(config.noColor == true)
    }

    @Test("Short CLI flags and --no-lock-mouse")
    func shortFlags() throws {
        let config = try CLIParser.parse(["-s", "0", "-t", "500", "--no-lock-mouse", "-h", "-v"])
        #expect(config.countdownSeconds == 0)
        #expect(config.timeoutSeconds == 500)
        #expect(config.lockMouse == false)
        #expect(config.lockMouseExplicitlySet == true)
        #expect(config.showHelp == true)
        #expect(config.showVersion == true)
    }

    @Test("Update and auto-update subcommand parsing")
    func subcommandParsing() throws {
        let updateCmd = try CLIParser.parse(["update", "--check", "--quiet", "--force"])
        #expect(updateCmd.command == .update(checkOnly: true, quiet: true, force: true))

        let enableCmd = try CLIParser.parse(["auto-update", "enable"])
        #expect(enableCmd.command == .autoUpdate(.enable))

        let disableCmd = try CLIParser.parse(["auto-update", "disable"])
        #expect(disableCmd.command == .autoUpdate(.disable))

        let statusCmd = try CLIParser.parse(["auto-update"])
        #expect(statusCmd.command == .autoUpdate(.status))
    }

    @Test("Conflicting --now and --seconds rejected")
    func conflictingNowAndSecondsRejected() {
        #expect(throws: CLIParseError.conflictingFlags("Cannot combine --now with --seconds.")) {
            _ = try CLIParser.parse(["--now", "--seconds", "5"])
        }
        #expect(throws: CLIParseError.conflictingFlags("Cannot combine --now with --seconds.")) {
            _ = try CLIParser.parse(["--seconds", "5", "--now"])
        }
    }

    @Test("Out-of-range and invalid arguments rejected")
    func outOfRangeValuesRejected() {
        #expect(throws: CLIParseError.self) {
            _ = try CLIParser.parse(["--seconds", "301"])
        }
        #expect(throws: CLIParseError.self) {
            _ = try CLIParser.parse(["--seconds", "-1"])
        }
        #expect(throws: CLIParseError.self) {
            _ = try CLIParser.parse(["--timeout", "0"])
        }
        #expect(throws: CLIParseError.self) {
            _ = try CLIParser.parse(["--timeout", "7201"])
        }
        #expect(throws: CLIParseError.self) {
            _ = try CLIParser.parse(["auto-update", "bogus"])
        }
    }

    @Test("DurationHelper parses seconds, minutes, compound values, and formats cleanly")
    func durationParsingAndFormatting() throws {
        #expect(try DurationHelper.parse("500") == 500)
        #expect(try DurationHelper.parse("500s") == 500)
        #expect(try DurationHelper.parse("5m") == 300)
        #expect(try DurationHelper.parse("1.5m") == 90)
        #expect(try DurationHelper.parse("2m 30s") == 150)
        #expect(try DurationHelper.parse("1h") == 3600)

        #expect(DurationHelper.formatHuman(500) == "8 min 20 sec")
        #expect(DurationHelper.formatHuman(120) == "2 min")
        #expect(DurationHelper.formatHuman(45) == "45 sec")
        #expect(DurationHelper.formatClock(500) == "08:20")
        #expect(DurationHelper.formatClock(3665) == "1:01:05")

        #expect(throws: DurationParseError.empty) {
            _ = try DurationHelper.parse("   ")
        }
        #expect(throws: DurationParseError.self) {
            _ = try DurationHelper.parse("abc")
        }
    }

    @Test("Updater version, SHA comparison, manifest decoding, and LaunchAgent plist")
    func updaterLogic() throws {
        #expect(Updater.isVersion("1.3.1", newerThan: "1.3.0") == true)
        #expect(Updater.isVersion("2.0.0", newerThan: "1.9.9") == true)
        #expect(Updater.isVersion("1.3.0", newerThan: "1.3.0") == false)
        #expect(Updater.isVersion("1.2.9", newerThan: "1.3.0") == false)

        let json = """
        {
          "version": "1.3.0",
          "sha": "abcdef1234567890",
          "shortSha": "abcdef1",
          "asset": "kh-macos-universal.tar.gz",
          "sha256": "deadbeef"
        }
        """.data(using: .utf8)!
        let manifest = try JSONDecoder().decode(UpdateManifest.self, from: json)
        #expect(manifest.version == "1.3.0")
        #expect(manifest.shortSha == "abcdef1")

        #expect(Updater.shouldUpdate(localVersion: "1.3.0", localSha: "1111111", remote: manifest) == true)
        #expect(Updater.shouldUpdate(localVersion: "1.3.0", localSha: "abcdef1234567890", remote: manifest) == false)

        let plist = Updater.renderLaunchAgentPlist(binaryPath: "/opt/homebrew/bin/kh")
        #expect(plist.contains("/opt/homebrew/bin/kh"))
        #expect(plist.contains(AppMeta.launchAgentLabel))
    }

    @Test("ANSI stripping and card right-border alignment")
    func ansiStrippingAndCardAlignment() {
        let colored = "\u{001B}[96m\u{001B}[1m◈ KeyboardHibernate\u{001B}[0m"
        #expect(TerminalUI.stripANSI(colored) == "◈ KeyboardHibernate")
        #expect(TerminalUI.displayWidth(colored) == 19)

        let ui = TerminalUI(noColor: true, isTTY: true, terminalColumns: 80)
        let card = ui.renderCard(lines: ["Short", "A slightly longer row here"])
        let lengths = Set(card.split(separator: "\n").map(\.count))
        #expect(lengths.count == 1)
    }

    @Test("Progress bar clamping and fill ratios")
    func progressBarClamping() {
        let ui = TerminalUI(noColor: true, isTTY: true)
        #expect(ui.buildProgressBar(ratio: -0.5, width: 10) == "[░░░░░░░░░░]")
        #expect(ui.buildProgressBar(ratio: 0.5, width: 10) == "[█████░░░░░]")
        #expect(ui.buildProgressBar(ratio: 1.5, width: 10) == "[██████████]")
    }

    @Test("AppleScript escaping handles backslashes and quotes")
    func appleScriptEscaping() {
        #expect(
            Feedback.escapeAppleScriptString(#"Say "hello\" world"#) == #"Say \"hello\\\" world"#
        )
    }

    @Test("Event mask blocks NX_SYSDEFINED and optionally mouse events")
    func eventMaskIncludesSysDefinedAndOptionalMouse() {
        let keyboardOnlyMask = KeyboardHibernator.buildEventMask(lockMouse: false)
        #expect((keyboardOnlyMask & (CGEventMask(1) << 14)) != 0)
        #expect((keyboardOnlyMask & (CGEventMask(1) << CGEventType.keyDown.rawValue)) != 0)
        #expect((keyboardOnlyMask & (CGEventMask(1) << CGEventType.leftMouseDown.rawValue)) == 0)

        let fullMask = KeyboardHibernator.buildEventMask(lockMouse: true)
        #expect((fullMask & (CGEventMask(1) << CGEventType.leftMouseDown.rawValue)) != 0)
        #expect((fullMask & (CGEventMask(1) << CGEventType.scrollWheel.rawValue)) != 0)
    }
}
