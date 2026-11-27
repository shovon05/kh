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
  <a href="#-how-it-works--permissions">How It Works</a> &nbsp;·&nbsp;
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

Once started, both keyboard and mouse/trackpad lock immediately with a live countdown progress bar:

```text
  ▸ Timer:  [███████████░░░░░░░░░░░] 50%  •  04:10 left (of 08:20)
```

---

## ✨ Features

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>⏱️ Interactive Timer &amp; Smart Conversion</h3>
      Run <code>kh</code> to pick <strong>1 min</strong>, <strong>2 min</strong>, <strong>5 min</strong>, or enter any custom duration (like <code>500</code>, <code>5m</code>, or <code>2m30s</code>). Automatically converts seconds into minutes &amp; seconds, confirms before locking, and displays a live timer progress bar.
    </td>
    <td width="50%" valign="top">
      <h3>🔄 Effortless Auto-Updating</h3>
      Every push to <code>main</code> publishes a signed universal macOS binary via GitHub Releases. Installed Macs auto-check quietly in the background (or via an optional <code>launchd</code> LaunchAgent and <code>kh update</code>).
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🛡️ Total Key, Media &amp; Pointer Lock</h3>
      Blocks <code>keyDown</code>, <code>keyUp</code>, <code>flagsChanged</code>, <code>NX_SYSDEFINED</code> media/brightness/volume keys, plus mouse &amp; trackpad clicks, cursor movement, and scrolling.
    </td>
    <td width="50%" valign="top">
      <h3>🖐️ Accidental-Wipe Wake Guard</h3>
      Requires holding <code>⌃ Ctrl + ⌥ Option + ⌘ Cmd</code> continuously for <strong>0.6s</strong> with a live wake bar — wiping across your bottom-left keys won't unlock prematurely.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🎨 Polished Terminal UX</h3>
      Pixel-aligned Unicode cards, smooth live timer &amp; wake bars, instant <code>Ctrl+C</code> cancellation, TTY/<code>NO_COLOR</code> awareness, and guaranteed cursor restoration.
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

To also enable the background auto-update LaunchAgent right away:

```bash
curl -fsSL https://raw.githubusercontent.com/shovon05/kh/main/scripts/install.sh | bash -s -- --auto-update
```

> Downloads the prebuilt universal binary (`arm64` + `x86_64`) from GitHub Releases in ~1 second (or falls back to building from source) into a user-writable directory (`/opt/homebrew/bin`, `/usr/local/bin`, or `~/.local/bin`) so updates never prompt for `sudo`.

### Build From Source

```bash
git clone https://github.com/shovon05/kh.git
cd kh
bash scripts/install.sh
```

### Requirements

- **macOS 12 (Monterey)** or later
- **Xcode Command Line Tools** (`xcode-select --install`) only if building from source

---

## 🚀 Usage & CLI Reference

```bash
# Interactive mode: choose 1m / 2m / 5m / custom (e.g. 500s -> 8m 20s) + lock keyboard & mouse
kh

# Non-interactive: start immediately for 500 seconds with mouse locked
kh --now --timeout 500 --lock-mouse

# 5-second countdown, keyboard-only, silent mode
kh --seconds 5 --timeout 2m --silent

# Update kh immediately from GitHub Releases
kh update
```

### Options & Subcommands

| Command / Flag | Description | Default |
| :--- | :--- | :--- |
| `kh` | Launch interactive timer prompt + lock keyboard & mouse | interactive |
| `kh update [--check] [--force]` | Check or install the latest GitHub Release binary | — |
| `kh auto-update <enable\|disable\|status>` | Manage background LaunchAgent (`StartInterval = 6h`) | `disabled` |
| `-s, --seconds <sec>` | Pre-hibernation countdown (`0–300`, skips interactive prompt) | `10` |
| `--now` | Hibernate immediately without a countdown | `off` |
| `-t, --timeout <dur>` | Auto-wake duration (`500`, `90s`, `5m`, `2m30s`; max `7200s`) | `off` |
| `-m, --lock-mouse` | Lock mouse/trackpad clicks, movement, and scrolling | `on` in prompt |
| `--no-lock-mouse` | Lock keyboard only (leaves trackpad active) | `off` |
| `--silent` | Disable lock/wake chimes and macOS notifications | `off` |
| `--no-color` | Disable ANSI colors (also respects `NO_COLOR` & pipes) | `auto` |
| `-v, --version` | Print version information | — |
| `-h, --help` | Show CLI help | — |

### Wake & Cancel Shortcuts

| Action | Shortcut | Notes |
| :--- | :--- | :--- |
| **Wake early** | Hold `⌃ Ctrl` + `⌥ Option` + `⌘ Cmd` for `0.6s` | Modifier-only hold prevents accidental wipes & keeps Space blocked |
| **Cancel** | `Ctrl + C` | Immediately cancels prompt/countdown or safely restores input |

---

## 🔄 Auto-Updates

Every push to `main` triggers [release.yml](.github/workflows/release.yml), which builds a universal macOS binary (`arm64` + `x86_64`), verifies tests, and updates the `latest` GitHub Release with `release-manifest.json` + SHA-256 checksums.

Installed Macs stay up to date in three ways:

1. **Instant manual sync:** Run `kh update` (or `kh update --check`) anytime.
2. **Throttled check on launch:** Running `kh` performs a non-blocking background check (at most once every 6 hours) and quietly updates the binary for your next launch without adding startup delay.
3. **Background LaunchAgent (optional):** Run `kh auto-update enable` (or install with `--auto-update`) to run `kh update --quiet` automatically at login and every 6 hours via `~/Library/LaunchAgents/com.shovon.kh.updater.plist`.

---

## 🔐 How It Works & Permissions

`kh` registers a `CGEventTap` at `.headInsertEventTap` on the active session (`cgSessionEventTap`) and drops matching keyboard, modifier, media (`NX_SYSDEFINED`), and optional pointer events before applications see them. If macOS temporarily times out the tap under heavy load, `kh` re-enables it automatically.

### Granting Accessibility Permission

On first launch, macOS requires **Accessibility** permission for your terminal app:

1. Run `kh` — macOS opens or requests the Accessibility prompt.
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Enable your terminal (**Terminal**, **iTerm2**, **Ghostty**, **Warp**, **Alacritty**, etc.).
4. Run `kh` again.

### Good to Know

- **Touch ID / Power button:** macOS handles the physical Power/Touch ID button below the event-tap layer, so pressing it will still sleep/lock your Mac.
- **Secure Keyboard Entry:** If your terminal has *Secure Keyboard Entry* enabled (or a password field is focused), macOS blocks all event taps by design. `kh` detects this and warns you before locking.

---

## 🗑️ Uninstallation

Cleanly stops/removes the LaunchAgent (if enabled), all installed binaries, `~/Library/Application Support/kh`, caches, and temporary files:

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
