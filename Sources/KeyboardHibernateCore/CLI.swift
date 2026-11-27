import Foundation

public struct AppConfig: Equatable {
    public var countdownSeconds: Int = 10
    public var timeoutSeconds: Int? = nil
    public var lockMouse: Bool = false
    public var silent: Bool = false
    public var noColor: Bool = false
    public var showHelp: Bool = false
    public var showVersion: Bool = false

    public init(
        countdownSeconds: Int = 10,
        timeoutSeconds: Int? = nil,
        lockMouse: Bool = false,
        silent: Bool = false,
        noColor: Bool = false,
        showHelp: Bool = false,
        showVersion: Bool = false
    ) {
        self.countdownSeconds = countdownSeconds
        self.timeoutSeconds = timeoutSeconds
        self.lockMouse = lockMouse
        self.silent = silent
        self.noColor = noColor
        self.showHelp = showHelp
        self.showVersion = showVersion
    }
}

public enum CLIParseError: Error, Equatable, CustomStringConvertible {
    case missingValue(flag: String)
    case invalidInteger(flag: String, value: String, min: Int, max: Int)
    case conflictingFlags(String)
    case unknownArgument(String)

    public var description: String {
        switch self {
        case .missingValue(let flag):
            return "\(flag) requires a numeric value."
        case .invalidInteger(let flag, let value, let min, let max):
            return "\(flag) expects an integer between \(min) and \(max) (got '\(value)')."
        case .conflictingFlags(let detail):
            return detail
        case .unknownArgument(let arg):
            return "Unknown argument '\(arg)'."
        }
    }
}

public enum CLIParser {
    public static func parse(_ arguments: [String]) throws -> AppConfig {
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
                case "-t", "--timeout":
                    config.timeoutSeconds = try parseBoundedInt(
                        flag: flag,
                        rawValue: inlineValue,
                        min: 1,
                        max: AppMeta.maxTimeoutSeconds
                    )
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
            case "-m", "--lock-mouse":
                config.lockMouse = true
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
            case "-t", "--timeout":
                i += 1
                guard i < arguments.count else {
                    throw CLIParseError.missingValue(flag: arg)
                }
                config.timeoutSeconds = try parseBoundedInt(
                    flag: arg,
                    rawValue: arguments[i],
                    min: 1,
                    max: AppMeta.maxTimeoutSeconds
                )
            default:
                throw CLIParseError.unknownArgument(arg)
            }

            i += 1
        }

        return config
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
}
