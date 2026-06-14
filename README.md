# 🧹 CleanMyKeyboard (`cmk`)

> A free, open-source macOS terminal app that safely locks your keyboard so you can wipe it clean — no accidental keypresses.

![macOS](https://img.shields.io/badge/macOS-12%2B-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![License](https://img.shields.io/badge/license-MIT-green)
![Open Source](https://img.shields.io/badge/open%20source-❤-red)

---

## ✨ Features

- **10-second countdown** before keyboard locks — giving you time to cancel
- **Fully blocks all keyboard input** once locked (using macOS Accessibility API)
- **Soft system sounds** play on lock and unlock
- **Native macOS notifications** — "Keyboard locked" / "Keyboard active"
- **One-chord unlock**: `Ctrl + Option + Cmd + Space`
- **Clean terminal UI** with live progress bar
- Zero dependencies — pure Swift + macOS frameworks

---

## 📦 Installation

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/shovon05/cmk/main/scripts/install.sh | bash
```

### Manual build from source

```bash
git clone https://github.com/shovon05/cmk.git
cd cmk
swift build -c release
sudo cp .build/release/cmk /usr/local/bin/cmk
```

### Requirements

- macOS 12 (Monterey) or later
- Xcode Command Line Tools (`xcode-select --install`)

---

## 🚀 Usage

```bash
cmk
```

That's it. Here's what happens:

1. `cmk` launches and shows a **10-second countdown**
2. Press `Ctrl+C` anytime during countdown to cancel
3. After countdown: keyboard is **fully locked** 🔒
4. A soft sound plays + macOS notification fires
5. Wipe your keyboard to your heart's content 🧹
6. Press **`Ctrl + Option + Cmd + Space`** to unlock
7. Another soft sound + notification: keyboard is back ✅

---

## 🔐 Permissions

`cmk` uses macOS's **Accessibility API** to intercept keyboard events system-wide. On first run:

1. macOS will show a permission dialog
2. Go to **System Settings → Privacy & Security → Accessibility**
3. Enable your Terminal app (Terminal.app, iTerm2, Warp, etc.)
4. Run `cmk` again

This permission is required — without it, keyboard blocking is not possible.

---

## 🔑 Unlock Shortcut

| Action | Shortcut |
|--------|----------|
| **Unlock keyboard** | `Ctrl` + `Option` + `Cmd` + `Space` |
| **Cancel (before lock)** | `Ctrl + C` |

---

## 🗑️ Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/cmk/main/scripts/uninstall.sh | bash
```

Or manually:

```bash
sudo rm /usr/local/bin/cmk
```

---

## 🏗️ Project Structure

```
cmk/
├── Sources/
│   └── cmk/
│       └── main.swift        # All app logic
├── scripts/
│   ├── install.sh            # One-liner installer
│   └── uninstall.sh          # Uninstaller
├── Package.swift             # Swift Package Manager manifest
└── README.md
```

---

## 🤝 Contributing

PRs welcome! Some ideas for contributions:

- [ ] Brew formula (`brew install cmk`)
- [ ] Custom countdown duration (`cmk --seconds 30`)
- [ ] Custom unlock combo support
- [ ] Menu bar status icon while locked
- [ ] Mouse disabling option

---

## 📄 License

MIT — free for everyone, forever.

---

## 💡 Inspired by

[CleanMyKeyboard on the App Store](https://apps.apple.com/app/cleanmykeyboard) — but fully free, open-source, and terminal-native.
