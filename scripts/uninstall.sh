#!/usr/bin/env bash
# KeyboardHibernate (kh) — Complete Uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/shovon05/kh/main/scripts/uninstall.sh | bash

set -euo pipefail
shopt -s nullglob

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo ""
echo -e "${CYAN}  ╭──────────────────────────────────────────╮${RESET}"
echo -e "${CYAN}  │${RESET}  ${BOLD}◈ KeyboardHibernate Uninstaller${RESET}         ${CYAN}│${RESET}"
echo -e "${CYAN}  ╰──────────────────────────────────────────╯${RESET}"
echo ""

removed_count=0

# 1. Gather potential binary locations (current 'kh' and legacy 'cmk')
candidate_paths=(
  "/usr/local/bin/kh"
  "/opt/homebrew/bin/kh"
  "$HOME/.local/bin/kh"
  "/usr/local/bin/cmk"
  "/opt/homebrew/bin/cmk"
  "$HOME/.local/bin/cmk"
)

for cmd in kh cmk; do
  while IFS= read -r path; do
    if [[ -n "$path" && ( -f "$path" || -L "$path" ) ]]; then
      candidate_paths+=("$path")
    fi
  done < <(which -a "$cmd" 2>/dev/null || true)
done

# Deduplicate safely without whitespace splitting
unique_candidates=()
while IFS= read -r line; do
  [[ -n "$line" ]] && unique_candidates+=("$line")
done < <(printf '%s\n' "${candidate_paths[@]}" | awk '!seen[$0]++')

echo -e "  ${BOLD}Checking for installed binaries...${RESET}"
for bin in "${unique_candidates[@]}"; do
  if [[ -f "$bin" || -L "$bin" ]]; then
    echo -e "  Removing: ${bin}"
    if [[ -w "$(dirname "$bin")" ]]; then
      rm -f "$bin"
    else
      sudo rm -f "$bin"
    fi
    removed_count=$((removed_count + 1))
  fi
done

# 2. Clean temporary directories & installer remnants
echo -e "  ${BOLD}Cleaning temporary files & caches...${RESET}"
tmp_base="${TMPDIR:-/tmp}"
tmp_base="${tmp_base%/}"
tmp_matches=(
  /tmp/kh*
  /tmp/cmk*
  "${tmp_base}"/kh*
  "${tmp_base}"/cmk*
)

for item in "${tmp_matches[@]}"; do
  if [[ -e "$item" ]]; then
    echo -e "  Removing: ${item}"
    rm -rf "$item" 2>/dev/null || sudo rm -rf "$item" 2>/dev/null || true
    removed_count=$((removed_count + 1))
  fi
done

# 3. Clean application support and user caches if any were ever created
for app_dir in \
  "$HOME/Library/Caches/kh" \
  "$HOME/Library/Caches/cmk" \
  "$HOME/Library/Application Support/kh" \
  "$HOME/Library/Application Support/cmk" \
  "$HOME/Library/Preferences/kh.plist" \
  "$HOME/Library/Preferences/com.shovon.kh.plist"; do
  if [[ -e "$app_dir" ]]; then
    echo -e "  Removing: ${app_dir}"
    rm -rf "$app_dir"
    removed_count=$((removed_count + 1))
  fi
done

# 4. Clean local repo build artifacts if run inside repository
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
REPO_DIR=""
if [[ -f "./Package.swift" && -d "./Sources/kh" ]]; then
  REPO_DIR="$(pwd)"
elif [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/../Package.swift" && -d "$SCRIPT_DIR/../Sources/kh" ]]; then
  REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

if [[ -n "$REPO_DIR" && ( -d "$REPO_DIR/.build" || -d "$REPO_DIR/.swiftpm" ) ]]; then
  echo -e "  Cleaning local build artifacts in ${REPO_DIR}..."
  rm -rf "${REPO_DIR}/.build" "${REPO_DIR}/.swiftpm"
  removed_count=$((removed_count + 1))
fi

echo ""
if command -v kh &>/dev/null; then
  echo -e "  ${RED}! Warning: A 'kh' binary is still found at: $(which kh)${RESET}"
elif command -v cmk &>/dev/null; then
  echo -e "  ${RED}! Warning: A 'cmk' binary is still found at: $(which cmk)${RESET}"
else
  echo -e "  ${GREEN}${BOLD}✓ Uninstallation complete!${RESET}"
  echo -e "  ${GREEN}Removed ${removed_count} item(s). Zero traces of KeyboardHibernate remain.${RESET}"
fi
echo ""
