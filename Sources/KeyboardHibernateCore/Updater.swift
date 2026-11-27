import Foundation
import CryptoKit
import Darwin
import MachO

public struct UpdateManifest: Codable, Equatable {
    public let version: String
    public let sha: String
    public let shortSha: String?
    public let asset: String?
    public let sha256: String?
    public let publishedAt: String?

    public init(
        version: String,
        sha: String,
        shortSha: String? = nil,
        asset: String? = nil,
        sha256: String? = nil,
        publishedAt: String? = nil
    ) {
        self.version = version
        self.sha = sha
        self.shortSha = shortSha
        self.asset = asset
        self.sha256 = sha256
        self.publishedAt = publishedAt
    }
}

public struct InstallState: Codable, Equatable {
    public var installedVersion: String
    public var installedSha: String?
    public var lastCheckedEpoch: TimeInterval?
    public var lastUpdatedNotice: String?

    public init(
        installedVersion: String = AppMeta.version,
        installedSha: String? = nil,
        lastCheckedEpoch: TimeInterval? = nil,
        lastUpdatedNotice: String? = nil
    ) {
        self.installedVersion = installedVersion
        self.installedSha = installedSha
        self.lastCheckedEpoch = lastCheckedEpoch
        self.lastUpdatedNotice = lastUpdatedNotice
    }
}

public enum UpdateStatus: Equatable {
    case upToDate(version: String, sha: String?)
    case updateAvailable(currentVersion: String, currentSha: String?, remote: UpdateManifest)
    case updated(fromVersion: String, toVersion: String, sha: String?)
}

public enum AutoUpdateAction: String, Equatable {
    case enable
    case disable
    case status
}

public enum UpdaterError: Error, CustomStringConvertible {
    case manifestUnavailable(String)
    case downloadFailed(String)
    case checksumMismatch(expected: String, actual: String)
    case extractionFailed(String)
    case verificationFailed(String)
    case permissionDenied(path: String)
    case launchAgentFailed(String)

    public var description: String {
        switch self {
        case .manifestUnavailable(let detail):
            return "Could not fetch update metadata: \(detail)"
        case .downloadFailed(let detail):
            return "Download failed: \(detail)"
        case .checksumMismatch(let expected, let actual):
            return "SHA-256 verification failed (expected \(expected.prefix(12))..., got \(actual.prefix(12))...)."
        case .extractionFailed(let detail):
            return "Could not extract update archive: \(detail)"
        case .verificationFailed(let detail):
            return "Downloaded binary failed verification: \(detail)"
        case .permissionDenied(let path):
            return "Cannot write to \(path) without elevated privileges. Re-run with 'kh update' interactively or install into a user-writable directory."
        case .launchAgentFailed(let detail):
            return "LaunchAgent configuration failed: \(detail)"
        }
    }
}

public enum Updater {
    public static var appSupportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/kh", isDirectory: true)
    }

    public static var stateFileURL: URL {
        appSupportDirectory.appendingPathComponent("state.json", isDirectory: false)
    }

    public static var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(AppMeta.launchAgentLabel).plist", isDirectory: false)
    }

    public static func currentExecutablePath() -> String {
        var size: UInt32 = 0
        _NSGetExecutablePath(nil, &size)
        var buffer = [CChar](repeating: 0, count: Int(size))
        if _NSGetExecutablePath(&buffer, &size) == 0 {
            let raw = String(cString: buffer)
            return URL(fileURLWithPath: raw).resolvingSymlinksInPath().path
        }
        return URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().path
    }

    public static func isDevelopmentBinary(path: String = currentExecutablePath()) -> Bool {
        path.contains("/.build/") || path.contains("/DerivedData/")
    }

    public static func loadState() -> InstallState {
        guard let data = try? Data(contentsOf: stateFileURL),
              let state = try? JSONDecoder().decode(InstallState.self, from: data) else {
            return InstallState()
        }
        return state
    }

    public static func saveState(_ state: InstallState) {
        try? FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: stateFileURL, options: .atomic)
        }
    }

    /// Consumes and clears any one-time notice saved by a background auto-update.
    public static func consumeUpdateNotice() -> String? {
        var state = loadState()
        guard let notice = state.lastUpdatedNotice else { return nil }
        state.lastUpdatedNotice = nil
        saveState(state)
        return notice
    }

    public static func isVersion(_ remote: String, newerThan local: String) -> Bool {
        let rParts = remote.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            .split(separator: ".").compactMap { Int($0) }
        let lParts = local.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            .split(separator: ".").compactMap { Int($0) }

        let count = max(rParts.count, lParts.count)
        for i in 0..<count {
            let r = i < rParts.count ? rParts[i] : 0
            let l = i < lParts.count ? lParts[i] : 0
            if r != l { return r > l }
        }
        return false
    }

    public static func shouldUpdate(localVersion: String, localSha: String?, remote: UpdateManifest) -> Bool {
        if isVersion(remote.version, newerThan: localVersion) {
            return true
        }
        if remote.version == localVersion,
           let localSha = localSha,
           !localSha.isEmpty,
           !remote.sha.isEmpty,
           localSha != remote.sha {
            return true
        }
        return false
    }

    public static func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func fetchManifest(timeout: TimeInterval = 5.0) throws -> UpdateManifest {
        guard let url = URL(string: AppMeta.releaseManifestURL) else {
            throw UpdaterError.manifestUnavailable("Invalid manifest URL.")
        }

        let (data, response, error) = synchronousGET(url: url, timeout: timeout)
        if let error = error {
            throw UpdaterError.manifestUnavailable(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw UpdaterError.manifestUnavailable("No HTTP response received.")
        }
        guard http.statusCode == 200, let data = data else {
            throw UpdaterError.manifestUnavailable("HTTP \(http.statusCode)")
        }

        do {
            return try JSONDecoder().decode(UpdateManifest.self, from: data)
        } catch {
            throw UpdaterError.manifestUnavailable("Invalid JSON manifest.")
        }
    }

    public static func checkForUpdate(timeout: TimeInterval = 5.0) throws -> UpdateStatus {
        let manifest = try fetchManifest(timeout: timeout)
        var state = loadState()
        state.lastCheckedEpoch = Date().timeIntervalSince1970
        saveState(state)

        if shouldUpdate(localVersion: AppMeta.version, localSha: state.installedSha, remote: manifest) {
            return .updateAvailable(
                currentVersion: AppMeta.version,
                currentSha: state.installedSha,
                remote: manifest
            )
        }
        return .upToDate(version: AppMeta.version, sha: state.installedSha)
    }

    public static func performUpdate(
        force: Bool = false,
        allowSudo: Bool = true,
        timeout: TimeInterval = 15.0
    ) throws -> UpdateStatus {
        let targetPath = currentExecutablePath()
        let manifest = try fetchManifest(timeout: timeout)
        var state = loadState()
        state.lastCheckedEpoch = Date().timeIntervalSince1970

        if !force && !shouldUpdate(localVersion: AppMeta.version, localSha: state.installedSha, remote: manifest) {
            saveState(state)
            return .upToDate(version: AppMeta.version, sha: state.installedSha)
        }

        let tarballURLString: String
        if let asset = manifest.asset, !asset.isEmpty {
            tarballURLString = "https://github.com/\(AppMeta.repoOwner)/\(AppMeta.repoName)/releases/latest/download/\(asset)"
        } else {
            tarballURLString = AppMeta.releaseTarballURL
        }

        guard let tarballURL = URL(string: tarballURLString) else {
            throw UpdaterError.downloadFailed("Invalid archive URL.")
        }

        let (archiveData, response, error) = synchronousGET(url: tarballURL, timeout: timeout)
        if let error = error {
            throw UpdaterError.downloadFailed(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, let archiveData = archiveData else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw UpdaterError.downloadFailed("HTTP \(code)")
        }

        if let expectedHash = manifest.sha256, !expectedHash.isEmpty {
            let actualHash = sha256Hex(of: archiveData)
            guard actualHash.lowercased() == expectedHash.lowercased() else {
                throw UpdaterError.checksumMismatch(expected: expectedHash, actual: actualHash)
            }
        }

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kh-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let archivePath = tmpDir.appendingPathComponent("kh.tar.gz")
        try archiveData.write(to: archivePath)

        let tarResult = runProcess("/usr/bin/tar", arguments: ["-xzf", archivePath.path, "-C", tmpDir.path])
        guard tarResult.status == 0 else {
            throw UpdaterError.extractionFailed(tarResult.stderr)
        }

        let extractedBinary = tmpDir.appendingPathComponent(AppMeta.command)
        guard FileManager.default.fileExists(atPath: extractedBinary.path) else {
            throw UpdaterError.extractionFailed("Binary '\(AppMeta.command)' missing in archive.")
        }

        _ = runProcess("/usr/bin/chmod", arguments: ["755", extractedBinary.path])
        if FileManager.default.isExecutableFile(atPath: "/usr/bin/codesign") {
            _ = runProcess("/usr/bin/codesign", arguments: ["--force", "--sign", "-", extractedBinary.path])
        }

        let verifyResult = runProcess(extractedBinary.path, arguments: ["--version"])
        guard verifyResult.status == 0 else {
            throw UpdaterError.verificationFailed("Extracted binary returned status \(verifyResult.status).")
        }

        try installBinary(from: extractedBinary.path, to: targetPath, allowSudo: allowSudo)

        state.installedVersion = manifest.version
        state.installedSha = manifest.sha
        saveState(state)

        return .updated(fromVersion: AppMeta.version, toVersion: manifest.version, sha: manifest.shortSha ?? manifest.sha)
    }

    /// Runs a throttled non-blocking check in the background while `kh` runs interactively.
    public static func triggerBackgroundAutoCheckIfDue() {
        guard ProcessInfo.processInfo.environment["KH_NO_AUTO_UPDATE"] == nil else { return }
        guard !isDevelopmentBinary() else { return }

        let state = loadState()
        let now = Date().timeIntervalSince1970
        if let last = state.lastCheckedEpoch, (now - last) < AppMeta.updateCheckIntervalSeconds {
            return
        }

        let targetDir = (currentExecutablePath() as NSString).deletingLastPathComponent
        guard FileManager.default.isWritableFile(atPath: targetDir) else {
            return
        }

        DispatchQueue.global(qos: .utility).async {
            guard let result = try? performUpdate(force: false, allowSudo: false, timeout: 4.0) else {
                return
            }
            if case .updated(_, let toVersion, let sha) = result {
                var updatedState = loadState()
                let short = sha.map { String($0.prefix(7)) } ?? ""
                let suffix = short.isEmpty ? "" : " (\(short))"
                updatedState.lastUpdatedNotice = "Auto-updated kh to v\(toVersion)\(suffix) in background — active on next run."
                saveState(updatedState)
            }
        }
    }

    // MARK: - LaunchAgent Management

    public static func renderLaunchAgentPlist(binaryPath: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(AppMeta.launchAgentLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
                <string>update</string>
                <string>--quiet</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>StartInterval</key>
            <integer>21600</integer>
            <key>StandardOutPath</key>
            <string>/dev/null</string>
            <key>StandardErrorPath</key>
            <string>/dev/null</string>
        </dict>
        </plist>
        """
    }

    public static func enableAutoUpdateAgent(binaryPath: String = currentExecutablePath()) throws {
        let targetDir = (binaryPath as NSString).deletingLastPathComponent
        guard FileManager.default.isWritableFile(atPath: targetDir) else {
            throw UpdaterError.permissionDenied(path: binaryPath)
        }

        let agentsDir = launchAgentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: agentsDir, withIntermediateDirectories: true)

        let plist = renderLaunchAgentPlist(binaryPath: binaryPath)
        try plist.write(to: launchAgentURL, atomically: true, encoding: .utf8)

        let domain = "gui/\(getuid())"
        _ = runProcess("/bin/launchctl", arguments: ["bootout", "\(domain)/\(AppMeta.launchAgentLabel)"])
        let bootstrap = runProcess("/bin/launchctl", arguments: ["bootstrap", domain, launchAgentURL.path])
        if bootstrap.status != 0 {
            let legacy = runProcess("/bin/launchctl", arguments: ["load", "-w", launchAgentURL.path])
            if legacy.status != 0 {
                throw UpdaterError.launchAgentFailed(bootstrap.stderr.isEmpty ? legacy.stderr : bootstrap.stderr)
            }
        }
    }

    public static func disableAutoUpdateAgent() {
        let domain = "gui/\(getuid())"
        _ = runProcess("/bin/launchctl", arguments: ["bootout", "\(domain)/\(AppMeta.launchAgentLabel)"])
        _ = runProcess("/bin/launchctl", arguments: ["unload", "-w", launchAgentURL.path])
        try? FileManager.default.removeItem(at: launchAgentURL)
    }

    public static func isAutoUpdateAgentEnabled() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    // MARK: - Helpers

    private static func installBinary(from sourcePath: String, to destinationPath: String, allowSudo: Bool) throws {
        let destURL = URL(fileURLWithPath: destinationPath)
        let destDir = destURL.deletingLastPathComponent()

        if FileManager.default.isWritableFile(atPath: destDir.path) {
            let stagedURL = destDir.appendingPathComponent(".\(AppMeta.command).tmp.\(UUID().uuidString)")
            try FileManager.default.copyItem(atPath: sourcePath, toPath: stagedURL.path)
            _ = runProcess("/usr/bin/chmod", arguments: ["755", stagedURL.path])
            if rename(stagedURL.path, destinationPath) != 0 {
                try? FileManager.default.removeItem(at: stagedURL)
                throw UpdaterError.permissionDenied(path: destinationPath)
            }
            return
        }

        guard allowSudo else {
            throw UpdaterError.permissionDenied(path: destinationPath)
        }

        let sudoInstall = runProcess("/usr/bin/sudo", arguments: ["install", "-m", "755", sourcePath, destinationPath], inheritTTY: true)
        guard sudoInstall.status == 0 else {
            throw UpdaterError.permissionDenied(path: destinationPath)
        }
    }

    private static func synchronousGET(url: URL, timeout: TimeInterval) -> (Data?, URLResponse?, Error?) {
        let semaphore = DispatchSemaphore(value: 0)
        var outData: Data?
        var outResponse: URLResponse?
        var outError: Error?

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.setValue("\(AppMeta.command)/\(AppMeta.version)", forHTTPHeaderField: "User-Agent")

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: config)

        session.dataTask(with: request) { data, response, error in
            outData = data
            outResponse = response
            outError = error
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .now() + timeout + 1.0)
        session.finishTasksAndInvalidate()
        return (outData, outResponse, outError)
    }

    private static func runProcess(
        _ launchPath: String,
        arguments: [String],
        inheritTTY: Bool = false
    ) -> (status: Int32, stdout: String, stderr: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        if !inheritTTY {
            task.standardOutput = outPipe
            task.standardError = errPipe
        }

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return (-1, "", error.localizedDescription)
        }

        if inheritTTY {
            return (task.terminationStatus, "", "")
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        return (
            task.terminationStatus,
            String(data: outData, encoding: .utf8) ?? "",
            String(data: errData, encoding: .utf8) ?? ""
        )
    }
}
