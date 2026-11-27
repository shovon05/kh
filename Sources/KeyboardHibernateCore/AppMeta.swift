import Foundation

public enum AppMeta {
    public static let name = "KeyboardHibernate"
    public static let command = "kh"
    public static let version = "1.3.0"
    public static let repoOwner = "shovon05"
    public static let repoName = "kh"
    public static let repoURL = "github.com/shovon05/kh"
    public static let releaseManifestURL = "https://github.com/shovon05/kh/releases/latest/download/release-manifest.json"
    public static let releaseTarballURL = "https://github.com/shovon05/kh/releases/latest/download/kh-macos-universal.tar.gz"
    public static let launchAgentLabel = "com.shovon.kh.updater"
    public static let wakeHoldDuration: TimeInterval = 0.6
    public static let maxCountdownSeconds = 300
    public static let maxTimeoutSeconds = 7200
    public static let updateCheckIntervalSeconds: TimeInterval = 6 * 3600
}
