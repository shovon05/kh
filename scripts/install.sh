#!/usr/bin/env bash
# KeyboardHibernate (kh) — Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/shovon05/kh/main/scripts/install.sh | bash

set -euo pipefail

REPO="shovon05/kh"
BINARY_NAME="kh"
ENABLE_AUTO_UPDATE=false

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

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
    --auto-update)
      ENABLE_AUTO_UPDATE=true
      shift
      ;;
    -h|--help)
      echo "Usage: install.sh [--prefix <dir>] [--auto-update]"
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

# 2. Choose a user-writable install directory whenever possible (required for passwordless auto-updates)
INSTALL_DIR=""
if [[ -n "${PREFIX:-}" ]]; then
  INSTALL_DIR="$PREFIX"
elif [[ -d "/opt/homebrew/bin" && -w "/opt/homebrew/bin" ]]; then
  INSTALL_DIR="/opt/homebrew/bin"
elif [[ -d "/usr/local/bin" && -w "/usr/local/bin" ]]; then
  INSTALL_DIR="/usr/local/bin"
elif [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
  INSTALL_DIR="$HOME/.local/bin"
elif [[ "$(uname -m)" == "arm64" && -d "/opt/homebrew/bin" ]]; then
  INSTALL_DIR="/opt/homebrew/bin"
else
  INSTALL_DIR="$HOME/.local/bin"
fi

# 3. Detect local source repo vs remote install
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
LOCAL_SOURCE=""

if [[ -f "./Package.swift" && -f "./Sources/kh/main.swift" ]]; then
  LOCAL_SOURCE="$(pwd)"
elif [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/../Package.swift" && -f "$SCRIPT_DIR/../Sources/kh/main.swift" ]]; then
  LOCAL_SOURCE="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

INSTALLED_SHA=""
BUILT_BINARY=""
TMP_DIR=""
cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT INT TERM

if [[ -n "$LOCAL_SOURCE" ]]; then
  if ! command -v swift &>/dev/null; then
    echo -e "${YELLOW}! Swift not found. Requesting Xcode Command Line Tools...${RESET}"
    xcode-select --install 2>/dev/null || true
    exit 1
  fi
  echo -e "  ${BOLD}Building from local source${RESET} ${DIM}(${LOCAL_SOURCE})${RESET}"
  cd "$LOCAL_SOURCE"
  swift build -c release
  BUILT_BINARY="${LOCAL_SOURCE}/.build/release/${BINARY_NAME}"
  INSTALLED_SHA="$(git rev-parse HEAD 2>/dev/null || true)"
else
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kh-install.XXXXXX")"

  MANIFEST_URL="https://github.com/${REPO}/releases/latest/download/release-manifest.json"
  TARBALL_URL="https://github.com/${REPO}/releases/latest/download/kh-macos-universal.tar.gz"

  if curl -fsSL --connect-timeout 3 "$MANIFEST_URL" -o "$TMP_DIR/manifest.json" 2>/dev/null && \
     curl -fsSL --connect-timeout 5 "$TARBALL_URL" -o "$TMP_DIR/kh.tar.gz" 2>/dev/null; then
    echo -e "  ${BOLD}Downloading prebuilt universal macOS release...${RESET}"
    EXPECTED_HASH="$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("sha256",""))' "$TMP_DIR/manifest.json" 2>/dev/null || true)"
    INSTALLED_SHA="$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("sha",""))' "$TMP_DIR/manifest.json" 2>/dev/null || true)"
    if [[ -n "$EXPECTED_HASH" ]]; then
      ACTUAL_HASH="$(shasum -a 256 "$TMP_DIR/kh.tar.gz" | awk '{print $1}')"
      if [[ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]]; then
        echo -e "${RED}✕ Checksum verification failed.${RESET}"
        exit 1
      fi
    fi
    tar -xzf "$TMP_DIR/kh.tar.gz" -C "$TMP_DIR"
    BUILT_BINARY="$TMP_DIR/${BINARY_NAME}"
  else
    if ! command -v swift &>/dev/null; then
      echo -e "${YELLOW}! Swift not found. Requesting Xcode Command Line Tools...${RESET}"
      xcode-select --install 2>/dev/null || true
      echo -e "${YELLOW}  Please re-run this installer once Xcode CLT finishes installing.${RESET}"
      exit 1
    fi
    echo -e "  ${BOLD}Cloning latest source from github.com/${REPO}...${RESET}"
    git clone --depth 1 "https://github.com/${REPO}.git" "$TMP_DIR/kh"
    cd "$TMP_DIR/kh"
    INSTALLED_SHA="$(git rev-parse HEAD 2>/dev/null || true)"
    echo -e "  ${BOLD}Compiling Swift release build...${RESET}"
    swift build -c release
    BUILT_BINARY="$TMP_DIR/kh/.build/release/${BINARY_NAME}"
  fi
fi

if [[ ! -f "$BUILT_BINARY" ]]; then
  echo -e "${RED}✕ Build failed: compiled binary not found.${RESET}"
  exit 1
fi

if command -v codesign &>/dev/null; then
  codesign --force --sign - "$BUILT_BINARY" 2>/dev/null || true
fi

# 4. Install binary
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

# 5. Record installed version & commit SHA for future auto-update comparisons
STATE_DIR="$HOME/Library/Application Support/kh"
mkdir -p "$STATE_DIR"
INSTALLED_VERSION="$("${INSTALL_DIR}/${BINARY_NAME}" --version 2>/dev/null | awk '{print $2}' || echo "1.3.0")"
cat > "${STATE_DIR}/state.json" <<EOF
{
  "installedVersion": "${INSTALLED_VERSION}",
  "installedSha": "${INSTALLED_SHA}",
  "lastCheckedEpoch": $(date +%s)
}
EOF

echo ""
echo -e "  ${GREEN}${BOLD}✓ kh v${INSTALLED_VERSION} installed to ${INSTALL_DIR}/${BINARY_NAME}${RESET}"
echo ""

if [[ "$ENABLE_AUTO_UPDATE" == true ]]; then
  "${INSTALL_DIR}/${BINARY_NAME}" auto-update enable || true
  echo ""
fi

if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
  echo -e "  ${YELLOW}! Note: ${INSTALL_DIR} is not in your \$PATH.${RESET}"
  echo -e "  Add it to ~/.zshrc:"
  echo -e "    ${BOLD}export PATH=\"${INSTALL_DIR}:\$PATH\"${RESET}"
  echo ""
fi

echo -e "  Run ${CYAN}${BOLD}kh${RESET} for the interactive timer prompt, or ${CYAN}${BOLD}kh update${RESET} anytime."
if [[ "$ENABLE_AUTO_UPDATE" == false ]]; then
  echo -e "  Run ${CYAN}${BOLD}kh auto-update enable${RESET} to sync updates automatically in the background."
fi
echo ""
echo -e "  ${YELLOW}! First run:${RESET} macOS will prompt for Accessibility permission."
echo -e "  ${DIM}System Settings → Privacy & Security → Accessibility → enable your Terminal.${RESET}"
echo ""
