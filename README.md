<div align="center">

<br />

<h1>❄️ KeyboardHibernate</h1>

<p>
  <strong>Hibernate your Mac keyboard (and trackpad) in one command so you can clean every key without a single stray keypress.</strong>
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
  <a href="#-how-it-works--permissions">How It Works</a> &nbsp;·&nbsp;
  <a href="#%EF%B8%8F-uninstallation">Uninstall</a>
</p>

<br />

</div>

```text
  ╭──────────────────────────────────────────────────────────╮
  │ ◈ KeyboardHibernate  v1.2.0                              │
  │ github.com/shovon05/kh                                   │
  ╰──────────────────────────────────────────────────────────╯

  ╭──────────────────────────────────────────────────────────╮
  │ ● INPUT HIBERNATING — SAFE TO CLEAN                      │
  │                                                          │
  │ ▸ Keys, modifiers, Space & media keys blocked            │
  │ ▸ Mouse & trackpad clicks/movement blocked               │
  │                                                          │
  │ Wake: Hold Ctrl + Option + Cmd for 0.6s                  │
  │ Auto-wake timer: 60s                                     │
  ╰──────────────────────────────────────────────────────────╯

  ▸ Wake:   [████████████░░░░░░] 67% (keep holding ⌃ ⌥ ⌘)
```

---

## ✨ Features

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🛡️ Total Key & Media Blocking</h3>
      Blocks <code>keyDown</code>, <code>keyUp</code>, <code>flagsChanged</code>, and <code>NX_SYSDEFINED</code> events — stopping Space, modifiers, brightness, volume, play/pause, dictation, and Spotlight keys cold.
    </td>
    <td width="50%" valign="top">
      <h3>🖐️ Accidental-Wipe Wake Guard</h3>
      Requires holding <code>⌃ Ctrl + ⌥ Option + ⌘ Cmd</code> continuously for <strong>0.6s</strong> with a live progress bar — wiping across your bottom-left corner keys won't unlock prematurely.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🖱️ Optional Trackpad & Mouse Lock</h3>
      Pass <code>--lock-mouse</code> (<code>-m</code>) to block clicks, drags, cursor movement, and scrolling while wiping around your trackpad.
    </td>
    <td width="50%" valign="top">
      <h3>⏱️ Safety Auto-Wake Timeout</h3>
      Pass <code>--timeout &lt;sec&gt;</code> (<code>-t</code>) to guarantee automatic input restoration after a set number of seconds.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🎨 Polished Terminal UX</h3>
      Pixel-aligned Unicode cards, smooth live progress bars, instant <code>Ctrl+C</code> cancellation, TTY/<code>NO_COLOR</code> awareness, and guaranteed cursor restoration.
    </td>
    <td width="50%" valign="top">
      <h3>🪶 Pure Swift, Zero Bloat</h3>
      Built exclusively on macOS native frameworks (<code>CoreGraphics</code>, <code>AppKit</code>, <code>Carbon</code>) with no background daemons and a zero-trace uninstaller.
    </td>
  </tr>
</table>

---

## 📦 Installation

### One-Line Installer (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/shovon05/kh/main/scripts/install.sh | bash
```

> Installs automatically into `/opt/homebrew/bin` (Apple Silicon), `/usr/local/bin`, or a custom directory via `PREFIX=/custom/dir`.

### Build From Source

```bash
git clone https://github.com/shovon05/kh.git
cd kh
bash scripts/install.sh
```

Or build manually with Swift Package Manager:

```bash
swift build -c release
codesign --force --sign - .build/release/kh
cp .build/release/kh /opt/homebrew/bin/kh   # or /usr/local/bin/kh
```

### Requirements

- **macOS 12 (Monterey)** or later
- **Xcode Command Line Tools** (`xcode-select --install`)

---

## 🚀 Usage & CLI Reference

```bash
# Default 10-second countdown before hibernating
kh

# Start immediately and lock trackpad/mouse too
kh --now --lock-mouse

# 5-second countdown with a 60-second auto-wake safety timer
kh --seconds 5 --timeout 60

# Silent mode (no chimes or desktop notifications)
kh --silent
```

### Options

| Flag | Description | Default |
| :--- | :--- | :--- |
| `-s, --seconds <sec>` | Countdown before hibernation (`0–300`, also supports `--seconds=N`) | `10` |
| `--now` | Hibernate immediately without a countdown | `off` |
| `-t, --timeout <sec>` | Auto-wake automatically after `N` seconds (`1–3600`) | `off` |
| `-m, --lock-mouse` | Also block mouse/trackpad clicks, movement, and scrolling | `off` |
| `--silent` | Disable lock/wake sounds and macOS notifications | `off` |
| `--no-color` | Disable ANSI colors (also respects `NO_COLOR` & non-TTY pipes) | `auto` |
| `-v, --version` | Print version information | — |
| `-h, --help` | Show CLI help | — |

### Wake & Cancel Shortcuts

| Action | Shortcut | Notes |
| :--- | :--- | :--- |
| **Wake input** | Hold `⌃ Ctrl` + `⌥ Option` + `⌘ Cmd` for `0.6s` | Modifier-only hold prevents accidental wipes & keeps Space blocked |
| **Cancel countdown** | `Ctrl + C` | Immediately cancels before hibernation begins |

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

Remove all installed binaries, temporary build directories, and caches with zero leftover daemons or config files:

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
├── .github/workflows/ci.yml             # macOS build, test & script checks
├── Sources/
│   ├── KeyboardHibernateCore/           # Core logic, CLI parser, UI & event tap
│   │   ├── AppMeta.swift
│   │   ├── AppRunner.swift
│   │   ├── CLI.swift
│   │   ├── Feedback.swift
│   │   ├── KeyboardHibernator.swift
│   │   └── TerminalUI.swift
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

- [x] Media & system-defined key blocking (`NX_SYSDEFINED`)
- [x] Accidental-wipe wake hold protection (`0.6s` hold guard)
- [x] Optional mouse & trackpad locking (`--lock-mouse`)
- [x] Safety auto-wake timer (`--timeout`)
- [ ] Homebrew formula (`brew install shovon05/tap/kh`)
- [ ] Optional menu bar status indicator while hibernating

---

<div align="center">

Released under the [MIT License](LICENSE). Built with pure Swift for macOS.

</div>
