# ❄️ KeyboardHibernate (`kh`)

> A free, open-source macOS terminal app that fully hibernates your keyboard so you can wipe it clean — every key, every modifier, completely blocked.

![macOS](https://img.shields.io/badge/macOS-12%2B-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![License](https://img.shields.io/badge/license-MIT-green)
![Open Source](https://img.shields.io/badge/open%20source-❤-red)

---

## ✨ Features

- **Customizable countdown** — 10s default (`--seconds <n>`), or instant hibernation (`--now`)
- **Full keyboard hibernation** — every key is blocked, including Space, modifiers, and function keys
- **No key leaks through** — event tap sits at `.headInsertEventTap` with automatic timeout recovery
- **Soft system audio feedback** — plays pleasant chime on hibernate and wake (or `--silent`)
- **Native macOS notifications** — "Keyboard hibernating" / "Keyboard awake"
- **Simple, secure wake chord**: hold `Ctrl + Option + Cmd` simultaneously
- **Clean terminal UI** with live progress bar and guaranteed cursor restoration
- **Zero dependencies** — pure Swift + macOS native frameworks
- **Zero-footprint uninstaller** — leaves no lingering files, caches, or background daemons

---

## 📦 Installation

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/shovon05/kh/main/scripts/install.sh | bash
```

### Manual build from source

```bash
git clone https://github.com/shovon05/kh.git
cd kh
swift build -c release
sudo cp .build/release/kh /usr/local/bin/kh
```

### Requirements

- macOS 12 (Monterey) or later
- Xcode Command Line Tools (`xcode-select --install`)

---

## 🚀 Usage

```bash
# Standard 10-second countdown
kh

# Custom countdown duration (e.g. 5 seconds)
kh --seconds 5

# Hibernate immediately without countdown
kh --now

# Run silently without sound effects or notifications
kh --silent

# Show help & all options
kh --help
```

### What happens when you run `kh`:

1. `kh` launches and displays a countdown with a live progress bar.
2. Press `Ctrl+C` anytime during the countdown to safely cancel.
3. Once the countdown ends, the keyboard **fully hibernates** ❄️.
4. A soft sound plays and a macOS notification fires.
5. Wipe and clean your keyboard freely 🧹.
6. Hold **`Ctrl + Option + Cmd`** simultaneously to wake.
7. Another soft sound plays, the awake screen shows, and your keyboard is instantly active ✅.

---

## 🔐 Permissions

`kh` uses macOS's **Accessibility API** to intercept keyboard events system-wide. On first run:

1. macOS will show a permission dialog.
2. Go to **System Settings → Privacy & Security → Accessibility**.
3. Enable your Terminal app (Terminal, iTerm2, Warp, Ghostty, Alacritty, etc.).
4. Run `kh` again.

> **Note:** macOS grants Accessibility to the terminal host running the binary. No special daemon or background helper is installed.

---

## 🔑 Wake Shortcut

| Action | Shortcut |
|--------|----------|
| **Wake keyboard** | Hold `Ctrl` + `Option` + `Cmd` simultaneously |
| **Cancel (before hibernate)** | `Ctrl + C` |

> **Note:** The wake chord uses **only modifier keys** held together. This ensures even Space is fully blocked during hibernation — no key of any kind can slip through while wiping keys.

---

## 🗑️ Complete Uninstallation

To completely uninstall `kh` with zero traces left behind:

```bash
curl -fsSL https://raw.githubusercontent.com/shovon05/kh/main/scripts/uninstall.sh | bash
```

Or from a local clone:

```bash
bash scripts/uninstall.sh
```

### What the uninstaller cleans:
- All installed binaries across system directories (`/usr/local/bin/kh`, `/opt/homebrew/bin/kh`, `~/.local/bin/kh`, and legacy `cmk`)
- Temporary build directories and installer remnants (`/tmp/kh*`)
- Local build caches (`.build/`, `.swiftpm/`)
- User application caches (if any)

Zero background services, daemons, or configuration files remain.

---

## 🏗️ Project Structure

```
kh/
├── Sources/
│   └── kh/
│       └── main.swift        # Complete app logic, CLI args, & event tap
├── scripts/
│   ├── install.sh            # Universal installer (local & remote)
│   └── uninstall.sh          # Zero-trace uninstaller
├── Package.swift             # Swift Package Manager manifest
├── LICENSE
└── README.md
```

---

## 🤝 Contributing

PRs and suggestions welcome!

- [ ] Homebrew formula (`brew install shovon05/tap/kh`)
- [ ] Mouse / trackpad disabling option (`kh --lock-mouse`)
- [ ] Menu bar status indicator while hibernating

---

## 📄 License

MIT — free for everyone, forever.
