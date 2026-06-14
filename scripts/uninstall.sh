#!/usr/bin/env bash
# CleanMyKeyboard — uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/shovon05/cmk/main/scripts/uninstall.sh | bash

set -e

INSTALL_DIR="/usr/local/bin"
BINARY_NAME="cmk"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo ""
echo -e "${CYAN}${BOLD}  🧹 CleanMyKeyboard — Uninstaller${RESET}"
echo ""

if [[ -f "${INSTALL_DIR}/${BINARY_NAME}" ]]; then
  sudo rm "${INSTALL_DIR}/${BINARY_NAME}"
  echo -e "${GREEN}  ✅  cmk has been removed from ${INSTALL_DIR}.${RESET}"
else
  echo -e "${RED}  cmk not found in ${INSTALL_DIR}. Nothing to remove.${RESET}"
fi

echo ""
