#!/usr/bin/env bash
# KeyboardHibernate (kh) — Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/shovon05/kh/main/scripts/install.sh | bash

set -eo pipefail

REPO="shovon05/kh"
BINARY_NAME="kh"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║      ❄️   KeyboardHibernate Installer    ║${RESET}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
echo ""

# 1. Verify macOS
if [[ "$(uname)" != "Darwin" ]]; then
  echo -e "${RED}✗ Error: kh only supports macOS.${RESET}"
  exit 1
fi

# 2. Verify Swift compiler / Xcode Command Line Tools
if ! command -v swift &>/dev/null; then
  echo -e "${YELLOW}⚠ Swift not found. Requesting Xcode Command Line Tools...${RESET}"
  xcode-select --install 2>/dev/null || true
  echo -e "${YELLOW}  Please re-run this installer once Xcode CLT finishes installing.${RESET}"
  exit 1
fi

# 3. Determine best install directory in PATH
INSTALL_DIR=""
if [[ -n "${PREFIX:-}" && -d "$PREFIX" ]]; then
  INSTALL_DIR="$PREFIX"
elif [[ ":$PATH:" == *":/usr/local/bin:"* ]] || [[ ! -d "/opt/homebrew/bin" ]]; then
  INSTALL_DIR="/usr/local/bin"
elif [[ ":$PATH:" == *":/opt/homebrew/bin:"* ]]; then
  INSTALL_DIR="/opt/homebrew/bin"
elif [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
  INSTALL_DIR="$HOME/.local/bin"
else
  INSTALL_DIR="/usr/local/bin"
fi

# 4. Check if running inside local source repository or remote
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
LOCAL_SOURCE=""

if [[ -f "./Package.swift" && -f "./Sources/kh/main.swift" ]]; then
  LOCAL_SOURCE="$(pwd)"
elif [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/../Package.swift" && -f "$SCRIPT_DIR/../Sources/kh/main.swift" ]]; then
  LOCAL_SOURCE="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

if [[ -n "$LOCAL_SOURCE" ]]; then
  echo -e "${BOLD}  Building from local source (${LOCAL_SOURCE})...${RESET}"
  cd "$LOCAL_SOURCE"
  swift build -c release
  BUILT_BINARY="${LOCAL_SOURCE}/.build/release/${BINARY_NAME}"
else
  TMP_DIR="$(mktemp -d /tmp/kh-install.XXXXXX)"
  trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

  echo -e "${BOLD}  Cloning latest release from https://github.com/${REPO}...${RESET}"
  git clone --depth 1 "https://github.com/${REPO}.git" "$TMP_DIR/kh"
  cd "$TMP_DIR/kh"

  echo -e "${BOLD}  Compiling (Swift release build)...${RESET}"
  swift build -c release
  BUILT_BINARY="$TMP_DIR/kh/.build/release/${BINARY_NAME}"
fi

if [[ ! -f "$BUILT_BINARY" ]]; then
  echo -e "${RED}✗ Build failed: compiled binary not found.${RESET}"
  exit 1
fi

# 5. Install binary to destination directory
echo -e "${BOLD}  Installing binary to ${INSTALL_DIR}/${BINARY_NAME}...${RESET}"

if [[ -w "$INSTALL_DIR" ]]; then
  cp "$BUILT_BINARY" "${INSTALL_DIR}/${BINARY_NAME}"
  chmod 755 "${INSTALL_DIR}/${BINARY_NAME}"
else
  sudo mkdir -p "$INSTALL_DIR"
  sudo cp "$BUILT_BINARY" "${INSTALL_DIR}/${BINARY_NAME}"
  sudo chmod 755 "${INSTALL_DIR}/${BINARY_NAME}"
fi

echo ""
echo -e "${GREEN}${BOLD}  ✅  kh installed successfully to ${INSTALL_DIR}/${BINARY_NAME}!${RESET}"
echo ""

# Check PATH warning
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
  echo -e "${YELLOW}  ⚠ Note: ${INSTALL_DIR} is not in your \$PATH.${RESET}"
  echo -e "  Add it to your shell configuration (e.g. ~/.zshrc):"
  echo -e "    ${BOLD}export PATH=\"${INSTALL_DIR}:\$PATH\"${RESET}"
  echo ""
fi

echo -e "  Run ${CYAN}${BOLD}kh${RESET} in your terminal to hibernate your keyboard."
echo -e "  Run ${CYAN}${BOLD}kh --help${RESET} for available options and shortcuts."
echo ""
echo -e "${YELLOW}  ⚠  First run:${RESET} macOS will prompt for Accessibility permission."
echo -e "  Go to ${BOLD}System Settings → Privacy & Security → Accessibility${RESET}"
echo -e "  and enable your Terminal app (Terminal, iTerm2, Warp, Ghostty, etc.)."
echo ""
