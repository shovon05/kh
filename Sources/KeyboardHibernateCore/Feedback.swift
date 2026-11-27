import Foundation
import AppKit

public enum Feedback {
    public static func playLockSound(silent: Bool) {
        playSound(named: ["Funk", "Pop", "Tink", "Morse"], silent: silent)
    }

    public static func playUnlockSound(silent: Bool) {
        playSound(named: ["Glass", "Hero", "Ping", "Purr"], silent: silent)
    }

    private static func playSound(named names: [String], silent: Bool) {
        guard !silent else { return }
        let block = {
            for name in names {
                if let sound = NSSound(named: NSSound.Name(name)) {
                    sound.volume = 0.4
                    sound.play()
                    return
                }
            }
            NSSound.beep()
        }

        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    public static func escapeAppleScriptString(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    public static func sendNotification(
        title: String,
        message: String,
        silent: Bool,
        completion: (() -> Void)? = nil
    ) {
        guard !silent else {
            completion?()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let escapedMessage = escapeAppleScriptString(message)
            let escapedTitle = escapeAppleScriptString(title)
            let script = "display notification \"\(escapedMessage)\" with title \"\(escapedTitle)\""

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                // Non-fatal: notifications are best-effort
            }

            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }
}
