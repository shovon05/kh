#!/usr/bin/env bash
# KeyboardHibernate (kh) — Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/shovon05/kh/main/scripts/install.sh | bash

set -euo pipefail

REPO="shovon05/kh"
BINARY_NAME="kh"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# Optional --prefix argument
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      if [[ $# -lt 2 ]]; then
        echo -e "${RED}✕ Error: --prefix requires a directory argument.${RESET}" >&2
        exit 1
      fi
      PREFIX="$2"
      shift 2
      ;;
    --prefix=*)
      PREFIX="${1#*=}"
      shift
      ;;
    -h|--help)
      echo "Usage: install.sh [--prefix <dir>]"
      exit 0
      ;;
    *)
      echo -e "${RED}✕ Error: Unknown argument '$1'.${RESET}" >&2
      exit 1
      ;;
  esac
done

echo ""
echo -e "${CYAN}  ╭──────────────────────────────────────────╮${RESET}"
echo -e "${CYAN}  │${RESET}  ${BOLD}◈ KeyboardHibernate Installer${RESET}           ${CYAN}│${RESET}"
echo -e "${CYAN}  ╰──────────────────────────────────────────╯${RESET}"
echo ""

# 1. Verify macOS
if [[ "$(uname)" != "Darwin" ]]; then
  echo -e "${RED}✕ Error: kh only supports macOS.${RESET}"
  exit 1
fi

# 2. Verify Swift compiler / Xcode Command Line Tools
if ! command -v swift &>/dev/null; then
  echo -e "${YELLOW}! Swift not found. Requesting Xcode Command Line Tools...${RESET}"
  xcode-select --install 2>/dev/null || true
  echo -e "${YELLOW}  Please re-run this installer once Xcode CLT finishes installing.${RESET}"
  exit 1
fi

# 3. Determine best install directory (prefer user-writable Homebrew bin on Apple Silicon)
INSTALL_DIR=""
if [[ -n "${PREFIX:-}" ]]; then
  INSTALL_DIR="$PREFIX"
elif [[ ":$PATH:" == *":/opt/homebrew/bin:"* && -d "/opt/homebrew/bin" ]]; then
  INSTALL_DIR="/opt/homebrew/bin"
elif [[ ":$PATH:" == *":/usr/local/bin:"* ]]; then
  INSTALL_DIR="/usr/local/bin"
elif [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
  INSTALL_DIR="$HOME/.local/bin"
elif [[ "$(uname -m)" == "arm64" && -d "/opt/homebrew/bin" ]]; then
  INSTALL_DIR="/opt/homebrew/bin"
else
  INSTALL_DIR="/usr/local/bin"
fi

# 4. Detect local repository vs remote install
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
LOCAL_SOURCE=""

if [[ -f "./Package.swift" && -f "./Sources/kh/main.swift" ]]; then
  LOCAL_SOURCE="$(pwd)"
elif [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/../Package.swift" && -f "$SCRIPT_DIR/../Sources/kh/main.swift" ]]; then
  LOCAL_SOURCE="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

if [[ -n "$LOCAL_SOURCE" ]]; then
  echo -e "  ${BOLD}Building from local source${RESET} ${DIM}(${LOCAL_SOURCE})${RESET}"
  cd "$LOCAL_SOURCE"
  swift build -c release
  BUILT_BINARY="${LOCAL_SOURCE}/.build/release/${BINARY_NAME}"
else
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kh-install.XXXXXX")"
  trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

  echo -e "  ${BOLD}Cloning latest source from github.com/${REPO}...${RESET}"
  git clone --depth 1 "https://github.com/${REPO}.git" "$TMP_DIR/kh"
  cd "$TMP_DIR/kh"

  echo -e "  ${BOLD}Compiling Swift release build...${RESET}"
  swift build -c release
  BUILT_BINARY="$TMP_DIR/kh/.build/release/${BINARY_NAME}"
fi

if [[ ! -f "$BUILT_BINARY" ]]; then
  echo -e "${RED}✕ Build failed: compiled binary not found.${RESET}"
  exit 1
fi

# Ad-hoc sign binary so macOS Gatekeeper/TCC handles it cleanly
if command -v codesign &>/dev/null; then
  codesign --force --sign - "$BUILT_BINARY" 2>/dev/null || true
fi

# 5. Install binary
echo -e "  ${BOLD}Installing binary to ${INSTALL_DIR}/${BINARY_NAME}...${RESET}"

if [[ -d "$INSTALL_DIR" && -w "$INSTALL_DIR" ]] || [[ ! -d "$INSTALL_DIR" && -w "$(dirname "$INSTALL_DIR")" ]]; then
  mkdir -p "$INSTALL_DIR"
  cp "$BUILT_BINARY" "${INSTALL_DIR}/${BINARY_NAME}"
  chmod 755 "${INSTALL_DIR}/${BINARY_NAME}"
else
  sudo mkdir -p "$INSTALL_DIR"
  sudo cp "$BUILT_BINARY" "${INSTALL_DIR}/${BINARY_NAME}"
  sudo chmod 755 "${INSTALL_DIR}/${BINARY_NAME}"
fi

echo ""
echo -e "  ${GREEN}${BOLD}✓ kh installed successfully to ${INSTALL_DIR}/${BINARY_NAME}${RESET}"
echo ""

if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
  echo -e "  ${YELLOW}! Note: ${INSTALL_DIR} is not in your \$PATH.${RESET}"
  echo -e "  Add it to your shell config (e.g. ~/.zshrc):"
  echo -e "    ${BOLD}export PATH=\"${INSTALL_DIR}:\$PATH\"${RESET}"
  echo ""
fi

echo -e "  Run ${CYAN}${BOLD}kh${RESET} in your terminal to hibernate your keyboard."
echo -e "  Run ${CYAN}${BOLD}kh --help${RESET} for options (countdown, auto-wake timeout, mouse lock)."
echo ""
echo -e "  ${YELLOW}! First run:${RESET} macOS will prompt for Accessibility permission."
echo -e "  ${DIM}System Settings → Privacy & Security → Accessibility → enable your Terminal.${RESET}"
echo ""
