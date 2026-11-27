import Foundation

public enum DurationParseError: Error, Equatable, CustomStringConvertible {
    case empty
    case invalidFormat(String)
    case outOfRange(seconds: Int, min: Int, max: Int)

    public var description: String {
        switch self {
        case .empty:
            return "Please enter a duration."
        case .invalidFormat(let input):
            return "Could not understand duration '\(input)'. Try seconds (e.g. 500 or 90s) or minutes (e.g. 5m or 2m30s)."
        case .outOfRange(let seconds, let min, let max):
            return "Duration \(seconds)s is out of range (\(min)–\(max) seconds)."
        }
    }
}

public enum DurationHelper {
    /// Parses user-friendly duration strings:
    /// - "500" or "500s" -> 500
    /// - "5m" -> 300
    /// - "1.5m" -> 90
    /// - "2m30s" or "2m 30s" -> 150
    /// - "1h" -> 3600
    public static func parse(
        _ rawInput: String,
        minSeconds: Int = 1,
        maxSeconds: Int = AppMeta.maxTimeoutSeconds
    ) throws -> Int {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            throw DurationParseError.empty
        }

        // Plain integer -> seconds
        if let plainSeconds = Int(trimmed) {
            guard plainSeconds >= minSeconds, plainSeconds <= maxSeconds else {
                throw DurationParseError.outOfRange(seconds: plainSeconds, min: minSeconds, max: maxSeconds)
            }
            return plainSeconds
        }

        // Match compound tokens like "1h 5m 30s" or "2m30s" or "1.5m"
        let compact = trimmed.replacingOccurrences(of: " ", with: "")
        let pattern = #"^(?:(\d+(?:\.\d+)?)h)?(?:(\d+(?:\.\d+)?)m)?(?:(\d+(?:\.\d+)?)s)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: compact, range: NSRange(compact.startIndex..., in: compact)) else {
            throw DurationParseError.invalidFormat(rawInput)
        }

        var hasAnyComponent = false
        var totalSeconds = 0.0

        let multipliers: [(index: Int, factor: Double)] = [
            (1, 3600.0),
            (2, 60.0),
            (3, 1.0)
        ]

        for (groupIdx, factor) in multipliers {
            let range = match.range(at: groupIdx)
            if range.location != NSNotFound, let swiftRange = Range(range, in: compact) {
                if let value = Double(compact[swiftRange]) {
                    hasAnyComponent = true
                    totalSeconds += value * factor
                }
            }
        }

        guard hasAnyComponent else {
            throw DurationParseError.invalidFormat(rawInput)
        }

        let rounded = Int(totalSeconds.rounded())
        guard rounded >= minSeconds, rounded <= maxSeconds else {
            throw DurationParseError.outOfRange(seconds: rounded, min: minSeconds, max: maxSeconds)
        }
        return rounded
    }

    /// Formats seconds into human-readable form, e.g. 500 -> "8 min 20 sec"
    public static func formatHuman(_ totalSeconds: Int) -> String {
        let clamped = max(0, totalSeconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let seconds = clamped % 60

        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hr") }
        if minutes > 0 { parts.append("\(minutes) min") }
        if seconds > 0 || parts.isEmpty { parts.append("\(seconds) sec") }
        return parts.joined(separator: " ")
    }

    /// Formats seconds as MM:SS (or H:MM:SS) for live progress bars
    public static func formatClock(_ totalSeconds: Int) -> String {
        let clamped = max(0, totalSeconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let seconds = clamped % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
