import Testing
import CoreGraphics
@testable import KeyboardHibernateCore

@Suite("KeyboardHibernateCore Tests")
struct KeyboardHibernateCoreTests {
    @Test("Default CLI config values")
    func defaultConfig() throws {
        let config = try CLIParser.parse([])
        #expect(config.countdownSeconds == 10)
        #expect(config.timeoutSeconds == nil)
        #expect(config.lockMouse == false)
        #expect(config.silent == false)
        #expect(config.noColor == false)
        #expect(config.showHelp == false)
        #expect(config.showVersion == false)
    }

    @Test("Valid long flags and inline = syntax")
    func validFlagsAndInlineEquals() throws {
        let config = try CLIParser.parse([
            "--seconds=5",
            "--timeout=120",
            "--lock-mouse",
            "--silent",
            "--no-color"
        ])
        #expect(config.countdownSeconds == 5)
        #expect(config.timeoutSeconds == 120)
        #expect(config.lockMouse == true)
        #expect(config.silent == true)
        #expect(config.noColor == true)
    }

    @Test("Short CLI flags")
    func shortFlags() throws {
        let config = try CLIParser.parse(["-s", "0", "-t", "45", "-m", "-h", "-v"])
        #expect(config.countdownSeconds == 0)
        #expect(config.timeoutSeconds == 45)
        #expect(config.lockMouse == true)
        #expect(config.showHelp == true)
        #expect(config.showVersion == true)
    }

    @Test("--now sets countdown to 0")
    func nowFlag() throws {
        let config = try CLIParser.parse(["--now"])
        #expect(config.countdownSeconds == 0)
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

    @Test("Out-of-range integer arguments rejected")
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
            _ = try CLIParser.parse(["--timeout", "3601"])
        }
    }

    @Test("Missing flag values and unknown flags rejected")
    func missingValueAndUnknownFlagRejected() {
        #expect(throws: CLIParseError.missingValue(flag: "--seconds")) {
            _ = try CLIParser.parse(["--seconds"])
        }
        #expect(throws: CLIParseError.missingValue(flag: "--timeout")) {
            _ = try CLIParser.parse(["--timeout"])
        }
        #expect(throws: CLIParseError.unknownArgument("--unknown")) {
            _ = try CLIParser.parse(["--unknown"])
        }
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
