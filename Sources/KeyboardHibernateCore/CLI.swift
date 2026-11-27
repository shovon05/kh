import Foundation

public enum AppCommand: Equatable {
    case run
    case update(checkOnly: Bool, quiet: Bool, force: Bool)
    case autoUpdate(AutoUpdateAction)
}

public struct AppConfig: Equatable {
    public var command: AppCommand = .run
    public var countdownSeconds: Int = 10
    public var timeoutSeconds: Int? = nil
    public var lockMouse: Bool = false
    public var lockMouseExplicitlySet: Bool = false
    public var hasExplicitTimingFlags: Bool = false
    public var silent: Bool = false
    public var noColor: Bool = false
    public var showHelp: Bool = false
    public var showVersion: Bool = false

    public init(
        command: AppCommand = .run,
        countdownSeconds: Int = 10,
        timeoutSeconds: Int? = nil,
        lockMouse: Bool = false,
        lockMouseExplicitlySet: Bool = false,
        hasExplicitTimingFlags: Bool = false,
        silent: Bool = false,
        noColor: Bool = false,
        showHelp: Bool = false,
        showVersion: Bool = false
    ) {
        self.command = command
        self.countdownSeconds = countdownSeconds
        self.timeoutSeconds = timeoutSeconds
        self.lockMouse = lockMouse
        self.lockMouseExplicitlySet = lockMouseExplicitlySet
        self.hasExplicitTimingFlags = hasExplicitTimingFlags
        self.silent = silent
        self.noColor = noColor
        self.showHelp = showHelp
        self.showVersion = showVersion
    }
}

public enum CLIParseError: Error, Equatable, CustomStringConvertible {
    case missingValue(flag: String)
    case invalidInteger(flag: String, value: String, min: Int, max: Int)
    case invalidDuration(flag: String, detail: String)
    case conflictingFlags(String)
    case invalidSubcommandArgument(String)
    case unknownArgument(String)

    public var description: String {
        switch self {
        case .missingValue(let flag):
            return "\(flag) requires a value."
        case .invalidInteger(let flag, let value, let min, let max):
            return "\(flag) expects an integer between \(min) and \(max) (got '\(value)')."
        case .invalidDuration(let flag, let detail):
            return "\(flag): \(detail)"
        case .conflictingFlags(let detail):
            return detail
        case .invalidSubcommandArgument(let detail):
            return detail
        case .unknownArgument(let arg):
            return "Unknown argument '\(arg)'."
        }
    }
}

public enum CLIParser {
    public static func parse(_ arguments: [String]) throws -> AppConfig {
        if let first = arguments.first {
            if first == "update" {
                return try parseUpdateSubcommand(Array(arguments.dropFirst()))
            }
            if first == "auto-update" {
                return try parseAutoUpdateSubcommand(Array(arguments.dropFirst()))
            }
        }

        var config = AppConfig()
        var didSetNow = false
        var didSetSeconds = false
        var i = 0

        while i < arguments.count {
            let arg = arguments[i]

            if let (flag, inlineValue) = splitEquals(arg) {
                switch flag {
                case "-s", "--seconds":
                    guard !didSetNow else {
                        throw CLIParseError.conflictingFlags("Cannot combine --now with \(flag).")
                    }
                    config.countdownSeconds = try parseBoundedInt(
                        flag: flag,
                        rawValue: inlineValue,
                        min: 0,
                        max: AppMeta.maxCountdownSeconds
                    )
                    didSetSeconds = true
                    config.hasExplicitTimingFlags = true
                case "-t", "--timeout":
                    config.timeoutSeconds = try parseDurationFlag(flag: flag, rawValue: inlineValue)
                    config.hasExplicitTimingFlags = true
                default:
                    throw CLIParseError.unknownArgument(arg)
                }
                i += 1
                continue
            }

            switch arg {
            case "-h", "--help":
                config.showHelp = true
            case "-v", "--version":
                config.showVersion = true
            case "--now":
                guard !didSetSeconds else {
                    throw CLIParseError.conflictingFlags("Cannot combine --now with --seconds.")
                }
                config.countdownSeconds = 0
                didSetNow = true
                config.hasExplicitTimingFlags = true
            case "-m", "--lock-mouse":
                config.lockMouse = true
                config.lockMouseExplicitlySet = true
            case "--no-lock-mouse", "--keyboard-only":
                config.lockMouse = false
                config.lockMouseExplicitlySet = true
            case "--silent":
                config.silent = true
            case "--no-color":
                config.noColor = true
            case "-s", "--seconds":
                guard !didSetNow else {
                    throw CLIParseError.conflictingFlags("Cannot combine --now with \(arg).")
                }
                i += 1
                guard i < arguments.count else {
                    throw CLIParseError.missingValue(flag: arg)
                }
                config.countdownSeconds = try parseBoundedInt(
                    flag: arg,
                    rawValue: arguments[i],
                    min: 0,
                    max: AppMeta.maxCountdownSeconds
                )
                didSetSeconds = true
                config.hasExplicitTimingFlags = true
            case "-t", "--timeout":
                i += 1
                guard i < arguments.count else {
                    throw CLIParseError.missingValue(flag: arg)
                }
                config.timeoutSeconds = try parseDurationFlag(flag: arg, rawValue: arguments[i])
                config.hasExplicitTimingFlags = true
            default:
                throw CLIParseError.unknownArgument(arg)
            }

            i += 1
        }

        return config
    }

    private static func parseUpdateSubcommand(_ args: [String]) throws -> AppConfig {
        var checkOnly = false
        var quiet = false
        var force = false
        var noColor = false
        var showHelp = false

        for arg in args {
            switch arg {
            case "--check":
                checkOnly = true
            case "--quiet", "-q":
                quiet = true
            case "--force", "-f":
                force = true
            case "--no-color":
                noColor = true
            case "-h", "--help":
                showHelp = true
            default:
                throw CLIParseError.unknownArgument(arg)
            }
        }

        return AppConfig(
            command: .update(checkOnly: checkOnly, quiet: quiet, force: force),
            noColor: noColor,
            showHelp: showHelp
        )
    }

    private static func parseAutoUpdateSubcommand(_ args: [String]) throws -> AppConfig {
        var noColor = false
        var showHelp = false
        var action: AutoUpdateAction?

        for arg in args {
            switch arg {
            case "enable":
                action = .enable
            case "disable":
                action = .disable
            case "status":
                action = .status
            case "--no-color":
                noColor = true
            case "-h", "--help":
                showHelp = true
            default:
                throw CLIParseError.invalidSubcommandArgument("Unknown auto-update action '\(arg)'. Use: enable, disable, or status.")
            }
        }

        if showHelp {
            return AppConfig(command: .autoUpdate(.status), noColor: noColor, showHelp: true)
        }

        let resolvedAction = action ?? .status
        return AppConfig(command: .autoUpdate(resolvedAction), noColor: noColor)
    }

    private static func splitEquals(_ arg: String) -> (String, String)? {
        guard arg.hasPrefix("-"), let eqIndex = arg.firstIndex(of: "=") else {
            return nil
        }
        let flag = String(arg[..<eqIndex])
        let value = String(arg[arg.index(after: eqIndex)...])
        return (flag, value)
    }

    private static func parseBoundedInt(flag: String, rawValue: String, min: Int, max: Int) throws -> Int {
        guard let value = Int(rawValue), value >= min, value <= max else {
            throw CLIParseError.invalidInteger(flag: flag, value: rawValue, min: min, max: max)
        }
        return value
    }

    private static func parseDurationFlag(flag: String, rawValue: String) throws -> Int {
        do {
            return try DurationHelper.parse(rawValue, minSeconds: 1, maxSeconds: AppMeta.maxTimeoutSeconds)
        } catch {
            throw CLIParseError.invalidDuration(flag: flag, detail: "\(error)")
        }
    }
}
