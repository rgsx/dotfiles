#!/usr/bin/env bash
# Shared helpers for dotfiles bootstrap scripts.

set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles-backup}"
DRY_RUN=0
SKIP_INTERACTIVE=0

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

log_info() {
  echo -e "${BLUE}→${RESET} $*"
}

log_ok() {
  echo -e "${GREEN}✓${RESET} $*"
}

log_warn() {
  echo -e "${YELLOW}!${RESET} $*" >&2
}

log_error() {
  echo -e "${RED}✗${RESET} $*" >&2
}

phase_header() {
  echo
  echo -e "${BLUE}════════════════════════════════════════${RESET}"
  echo -e "${BLUE}  $*${RESET}"
  echo -e "${BLUE}════════════════════════════════════════${RESET}"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] $*"
    return 0
  fi
  "$@"
}

confirm() {
  local prompt="$1"
  if [[ "$SKIP_INTERACTIVE" -eq 1 ]]; then
    return 0
  fi
  read -r -p "$prompt [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    run_cmd mkdir -p "$dir"
  fi
}

run_step() {
  local message="$1"
  shift
  echo -n "  ${message}... "
  if run_cmd "$@"; then
    echo -e "${GREEN}ok${RESET}"
    return 0
  fi
  echo -e "${RED}failed${RESET}"
  return 1
}

parse_common_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --skip-interactive)
        SKIP_INTERACTIVE=1
        shift
        ;;
      *)
        return 0
        ;;
    esac
  done
}

load_homebrew_path() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

load_volta_path() {
  export VOLTA_HOME="${VOLTA_HOME:-$HOME/.volta}"
  export PATH="$VOLTA_HOME/bin:$PATH"
}

abort_phase() {
  local phase="$1"
  local reason="$2"
  log_error "Phase ${phase} failed: ${reason}"
  exit 1
}

pass_phase() {
  local phase="$1"
  log_ok "Phase ${phase} complete — safe to continue"
}
