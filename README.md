<div align="center">

<br />

<h1>❄️ KeyboardHibernate</h1>

<p>
  <strong>Hibernate your Mac keyboard &amp; trackpad with an interactive timer, live progress bar, and automatic GitHub Release updates.</strong>
</p>

<p>
  <img src="https://img.shields.io/badge/macOS-12%2B-0A84FF?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 12+" />
  <img src="https://img.shields.io/badge/Swift-5.9%2B-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 5.9+" />
  <img src="https://img.shields.io/badge/Dependencies-Zero-30D158?style=for-the-badge" alt="Zero Dependencies" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-64D2FF?style=for-the-badge" alt="MIT License" /></a>
</p>

<p>
  <a href="#-installation">Install</a> &nbsp;·&nbsp;
  <a href="#-features">Features</a> &nbsp;·&nbsp;
  <a href="#-usage--cli-reference">CLI Reference</a> &nbsp;·&nbsp;
  <a href="#-auto-updates">Auto-Updates</a> &nbsp;·&nbsp;
  <a href="#-how-it-works-permissions--faq">Permissions &amp; FAQ</a> &nbsp;·&nbsp;
  <a href="#%EF%B8%8F-uninstallation">Uninstall</a>
</p>

<br />

</div>

```text
  ╭──────────────────────────────────────────────────────────╮
  │ ◈ KeyboardHibernate  v1.3.0                              │
  │ github.com/shovon05/kh                                   │
  ╰──────────────────────────────────────────────────────────╯

  How long do you want to hibernate?

    [1]  1 min    (60 sec)
    [2]  2 min    (120 sec)
    [3]  5 min    (300 sec)
    [4]  Custom   (e.g. 500, 90s, 5m, 2m30s)
    [5]  No timer (stay locked until ⌃ ⌥ ⌘ wake)

  Select [1–5] or enter duration (default 1): 500

  ╭──────────────────────────────────────────────────────────╮
  │ Duration:  8 min 20 sec (500s)                           │
  │ Locking:   Keyboard + Mouse & Trackpad                   │
  │ Wake:      Hold Ctrl + Option + Cmd (0.6s)               │
  ╰──────────────────────────────────────────────────────────╯

  ▸ Press Enter to start hibernating (or Ctrl+C to cancel):
```

Once you press **Enter**, both your keyboard and mouse/trackpad lock immediately and a live progress bar tracks your timer:

```text
  ▸ Timer:  [███████████░░░░░░░░░░░] 50%  •  04:10 left (of 08:20)
```

---

## ✨ Features

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>⏱️ Interactive Timer &amp; Smart Conversion</h3>
      Run <code>kh</code> to pick <strong>1 min</strong>, <strong>2 min</strong>, <strong>5 min</strong>, or enter any custom duration (like <code>500</code>, <code>5m</code>, or <code>2m30s</code>). Converts seconds into minutes &amp; seconds, asks you to confirm, and renders a live progress bar.
    </td>
    <td width="50%" valign="top">
      <h3>🔄 Automatic GitHub Updates</h3>
      Every push to <code>main</code> builds a signed universal macOS binary on GitHub Releases. Installed Macs auto-check quietly (or via an optional <code>launchd</code> LaunchAgent and <code>kh update</code>) without breaking Accessibility permissions.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🛡️ Total Key, Media &amp; Pointer Lock</h3>
      Blocks <code>keyDown</code>, <code>keyUp</code>, <code>flagsChanged</code>, <code>NX_SYSDEFINED</code> media/brightness/volume keys, plus mouse &amp; trackpad clicks, cursor movement, and scrolling.
    </td>
    <td width="50%" valign="top">
      <h3>🖐️ Accidental-Wipe Wake Guard</h3>
      Requires holding <code>⌃ Ctrl + ⌥ Option + ⌘ Cmd</code> continuously for <strong>0.6s</strong> with a live wake bar — wiping across your bottom-left corner keys won't unlock prematurely.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🎨 Polished Terminal UX</h3>
      Pixel-aligned Unicode cards, smooth live timer &amp; wake bars, instant <code>Ctrl+C</code> cancellation before locking, TTY/<code>NO_COLOR</code> awareness, and guaranteed cursor restoration.
    </td>
    <td width="50%" valign="top">
      <h3>🪶 Pure Swift, Zero Bloat</h3>
      Built exclusively on native macOS frameworks (<code>CoreGraphics</code>, <code>AppKit</code>, <code>Carbon</code>, <code>CryptoKit</code>) with SHA-256 verified updates and a zero-trace uninstaller.
    </td>
  </tr>
</table>

---

## 📦 Installation

### One-Line Installer (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/shovon05/kh/main/scripts/install.sh | bash
```

To also enable automatic background updates right away:

```bash
curl -fsSL https://raw.githubusercontent.com/shovon05/kh/main/scripts/install.sh | bash -s -- --auto-update
```

> **How installation works:** Downloads the prebuilt universal binary (`arm64` + `x86_64`) from GitHub Releases in ~1 second (or falls back to compiling from source) into a **user-writable** folder (`/opt/homebrew/bin`, `/usr/local/bin`, or `~/.local/bin`). Keeping it user-writable ensures background updates never get stuck asking for `sudo`.

### Build From Source

```bash
git clone https://github.com/shovon05/kh.git
cd kh
bash scripts/install.sh --auto-update
```

### Requirements

- **macOS 12 (Monterey)** or later
- **Xcode Command Line Tools** (`xcode-select --install`) only if building from source

---

## 🚀 Usage & CLI Reference

### Interactive Mode vs. Direct Flags

- **Interactive mode (`kh` with no timing flags):** Shows the preset menu (`1m`, `2m`, `5m`, `Custom`, `No timer`), converts custom inputs (e.g. `500` → `8 min 20 sec`), asks you to press **Enter**, and locks **both keyboard and mouse/trackpad** immediately. Pass `--no-lock-mouse` if you want keyboard-only in interactive mode.
- **Direct CLI mode (`--now`, `-s`, or `-t`):** Skips the interactive prompt (ideal for scripts/aliases). Locks the keyboard by default; add `-m` / `--lock-mouse` to lock mouse & trackpad too.

```bash
# 1. Interactive wizard (presets + custom seconds conversion + keyboard & mouse lock)
kh

# 2. Direct CLI: lock immediately for 500 seconds (keyboard + mouse)
kh --now --timeout 500 --lock-mouse

# 3. Direct CLI: 5-second countdown, 2-minute timer, keyboard-only, silent
kh --seconds 5 --timeout 2m --silent

# 4. Update kh immediately or check auto-update status
kh update
kh auto-update status
```

### Supported Duration Formats

Anywhere a duration is accepted (the interactive prompt or `-t` / `--timeout`), you can write:

- Plain seconds: `500` or `500s` (converted to `8 min 20 sec`)
- Minutes / hours: `5m`, `1.5m`, `1h`
- Compound: `2m30s` or `2m 30s`
- Range: `1` second up to `7200` seconds (2 hours)

### Options & Subcommands

| Command / Flag | Description | Default |
| :--- | :--- | :--- |
| `kh` | Launch interactive timer prompt + lock keyboard & mouse | interactive |
| `kh update [--check] [--force]` | Check or install the latest GitHub Release binary | — |
| `kh auto-update <enable\|disable\|status>` | Manage background LaunchAgent (`StartInterval = 6h`) | `disabled` |
| `-s, --seconds <sec>` | Pre-hibernation countdown (`0–300`, skips interactive prompt) | `10` |
| `--now` | Hibernate immediately without a countdown | `off` |
| `-t, --timeout <dur>` | Auto-wake duration (`1s–7200s`, e.g. `500`, `5m`, `2m30s`) | `off` |
| `-m, --lock-mouse` | Lock mouse/trackpad clicks, movement, and scrolling | `on` in prompt |
| `--no-lock-mouse` | Lock keyboard only (leaves trackpad active) | `off` |
| `--silent` | Disable lock/wake chimes and macOS notifications | `off` |
| `--no-color` | Disable ANSI colors (also respects `NO_COLOR` & pipes) | `auto` |
| `-v, --version` | Print version information | — |
| `-h, --help` | Show CLI help | — |

### Wake & Cancel Shortcuts

| Action | Shortcut | Important Notes |
| :--- | :--- | :--- |
| **Wake early** | Hold `⌃ Ctrl` + `⌥ Option` + `⌘ Cmd` for `0.6s` | Works anytime during hibernation (even if mouse is locked). A live wake bar fills over `0.6s` so wiping bottom-left keys won't unlock by accident. |
| **Cancel setup** | `Ctrl + C` | Cancels at the duration prompt or during the `--seconds` countdown before input is locked. Once hibernating, `Ctrl+C` is blocked along with all other keys — use the wake chord above. |

---

## 🔄 Auto-Updates

Every push to `main` triggers [release.yml](.github/workflows/release.yml), which runs all tests, compiles a universal macOS binary (`arm64` + `x86_64`), and publishes `kh-macos-universal.tar.gz` + `release-manifest.json` (containing version, commit SHA, and SHA-256 checksum) to the `latest` GitHub Release.

Installed devices stay up to date in three ways:

1. **Manual instant update:** Run `kh update` (or `kh update --check`).
2. **Throttled check on launch:** Running `kh` performs a non-blocking background check at most once every **6 hours** (disable with `KH_NO_AUTO_UPDATE=1`). If a newer version or commit SHA is published, it downloads and verifies it silently so the **next run** uses the latest build—never delaying startup or interrupting cleaning.
3. **Background LaunchAgent (`launchd`):** Run `kh auto-update enable` (or install with `--auto-update`) to run `kh update --quiet` automatically at login and every 6 hours via `~/Library/LaunchAgents/com.shovon.kh.updater.plist`.

### Security & Update Guarantees

- **SHA-256 verified:** Every downloaded archive is verified against `release-manifest.json` using Apple `CryptoKit` before extraction.
- **Pre-swap verification:** The extracted binary is ad-hoc signed and smoke-tested (`kh --version`) before atomically replacing the installed binary.
- **No `sudo` traps in background:** Background updates only write to user-writable locations (`/opt/homebrew/bin`, `~/.local/bin`, etc.); if installed to a root-owned path, `kh update` uses `sudo` only when run interactively.
- **State tracking:** Installed version and commit SHA are stored in `~/Library/Application Support/kh/state.json` so even rolling `main` commits (without version bumps) are detected.

---

## 🔐 How It Works, Permissions & FAQ

`kh` registers a `CGEventTap` at `.headInsertEventTap` on the active session (`cgSessionEventTap`) and drops matching keyboard, modifier, media (`NX_SYSDEFINED`), and optional pointer events before macOS apps see them. If macOS temporarily times out the tap under heavy load, `kh` re-enables it automatically.

### Granting Accessibility Permission

On first launch, macOS requires **Accessibility** permission for your **Terminal app** (not the `kh` binary itself — meaning **auto-updates keep your permission intact**):

1. Run `kh` — macOS opens or requests the Accessibility prompt.
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Enable your terminal (**Terminal**, **iTerm2**, **Ghostty**, **Warp**, **Alacritty**, etc.).
4. Run `kh` again.

### Troubleshooting & Caveats

- **Keys still go through during hibernation:**
  1. Check that your *current* terminal app is enabled in **System Settings → Privacy & Security → Accessibility**.
  2. Check that **Secure Keyboard Entry** is disabled (e.g., `Terminal → Secure Keyboard Entry` in the menu bar). macOS blocks all event taps while Secure Keyboard Entry or a password prompt is active; `kh` detects this and prints a warning.
- **Touch ID / Power button still sleeps/locks the Mac:** macOS handles the physical Power/Touch ID button in hardware below the `CGEventTap` layer, so avoid pressing it while wiping.
- **`kh: command not found` after install:** If installed to `~/.local/bin`, add `export PATH="$HOME/.local/bin:$PATH"` to `~/.zshrc` and restart your terminal.

---

## 🗑️ Uninstallation

Cleanly unloads and removes the LaunchAgent (if enabled), all installed binaries, `~/Library/Application Support/kh`, caches, and temporary files:

```bash
curl -fsSL https://raw.githubusercontent.com/shovon05/kh/main/scripts/uninstall.sh | bash
```

Or locally:

```bash
bash scripts/uninstall.sh
```

---

## 🏗️ Project Structure & Development

```text
kh/
├── .github/workflows/
│   ├── ci.yml                           # macOS build, test & script checks
│   └── release.yml                      # Universal release builder on main/tags
├── Sources/
│   ├── KeyboardHibernateCore/           # Core logic, CLI, UI, updater & event tap
│   │   ├── AppMeta.swift
│   │   ├── AppRunner.swift
│   │   ├── CLI.swift
│   │   ├── DurationHelper.swift
│   │   ├── Feedback.swift
│   │   ├── KeyboardHibernator.swift
│   │   ├── TerminalUI.swift
│   │   └── Updater.swift
│   └── kh/
│       └── main.swift                   # Thin CLI entrypoint
├── Tests/
│   └── KeyboardHibernateCoreTests/      # Swift Testing unit suite
├── scripts/
│   ├── install.sh                       # Universal macOS installer
│   └── uninstall.sh                     # Zero-trace uninstaller
├── Package.swift                        # Swift Package Manager manifest
├── LICENSE                              # MIT License
└── README.md
```

Run build & tests locally:

```bash
swift build
swift test

# If running with Xcode Command Line Tools only (without full Xcode):
swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

---

## 🗺️ Roadmap

- [x] Interactive duration prompt (`1m`, `2m`, `5m`, custom seconds → minutes conversion)
- [x] Live hibernation timer progress bar
- [x] Media & system-defined key blocking (`NX_SYSDEFINED`)
- [x] Accidental-wipe wake hold protection (`0.6s` hold guard)
- [x] Mouse & trackpad locking (`--lock-mouse`)
- [x] Universal GitHub Releases + automatic background updates (`kh update`, `kh auto-update`)
- [ ] Homebrew formula (`brew install shovon05/tap/kh`)
- [ ] Optional menu bar status indicator while hibernating

---

<div align="center">

Released under the [MIT License](LICENSE). Built with pure Swift for macOS.

</div>
