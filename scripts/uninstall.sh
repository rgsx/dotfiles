#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/symlinks.sh
source "$SCRIPT_DIR/lib/symlinks.sh"

BREW_CLEANUP=0
VOLTA_CLEAN=0
ZINIT_CLEAN=0
NVIM_CLEAN=0
SSH_CLEAN=0
REMOVE_HOMEBREW=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Undo dotfiles symlinks and optionally remove installed artifacts.
Does NOT remove Xcode or Command Line Tools.

Options:
  --brew-cleanup      Remove Homebrew packages not in Brewfile
  --volta-clean       Remove ~/.volta
  --zinit-clean       Remove ~/.local/share/zinit
  --nvim-clean        Remove Neovim data/state directories
  --ssh-clean         Remove generated SSH keys from active profile
  --remove-homebrew   Uninstall Homebrew (destructive)
  --dry-run           Show actions without executing
  --skip-interactive  Skip confirmation prompts
  -h, --help          Show this help
EOF
}

parse_uninstall_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --brew-cleanup) BREW_CLEANUP=1; shift ;;
      --volta-clean) VOLTA_CLEAN=1; shift ;;
      --zinit-clean) ZINIT_CLEAN=1; shift ;;
      --nvim-clean) NVIM_CLEAN=1; shift ;;
      --ssh-clean) SSH_CLEAN=1; shift ;;
      --remove-homebrew) REMOVE_HOMEBREW=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      --skip-interactive) SKIP_INTERACTIVE=1; shift ;;
      -h | --help) usage; exit 0 ;;
      *) shift ;;
    esac
  done
}

remove_dir() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] rm -rf $dir"
    else
      rm -rf "$dir"
      log_ok "Removed $dir"
    fi
  fi
}

clean_ssh_keys() {
  # shellcheck source=scripts/lib/ssh-keys.sh
  source "$SCRIPT_DIR/lib/ssh-keys.sh"
  local config_file entries key_path

  config_file="$(resolve_active_profile_config)" || return 0
  entries="$(parse_identity_entries "$config_file" | dedupe_identity_paths)"

  if ! confirm "Remove SSH keys listed in ${config_file}?"; then
    return 0
  fi

  while IFS='|' read -r _host key_path _comment; do
    [[ -z "$key_path" ]] && continue
    if [[ -f "$key_path" ]]; then
      run_cmd rm -f "$key_path" "${key_path}.pub"
      log_ok "Removed $key_path"
    fi
  done <<< "$entries"
}

main() {
  parse_uninstall_flags "$@"

  phase_header "Uninstall dotfiles environment"

  if ! confirm "Remove dotfiles symlinks from \$HOME?"; then
    log_info "Aborted"
    exit 0
  fi

  remove_symlinks
  restore_backups

  if [[ "$BREW_CLEANUP" -eq 1 ]]; then
    load_homebrew_path
    if command_exists brew && [[ -f "$HOME/.config/homebrew/brewfile" ]]; then
      run_step "Brew bundle cleanup" \
        brew bundle cleanup --force --file="$HOME/.config/homebrew/brewfile"
    fi
  fi

  [[ "$VOLTA_CLEAN" -eq 1 ]] && remove_dir "$HOME/.volta"
  [[ "$ZINIT_CLEAN" -eq 1 ]] && remove_dir "$HOME/.local/share/zinit"
  if [[ "$NVIM_CLEAN" -eq 1 ]]; then
    remove_dir "$HOME/.local/share/nvim"
    remove_dir "$HOME/.local/state/nvim"
  fi
  [[ "$SSH_CLEAN" -eq 1 ]] && clean_ssh_keys

  if [[ "$REMOVE_HOMEBREW" -eq 1 ]]; then
    if confirm "Uninstall Homebrew entirely?"; then
      log_warn "Run the official Homebrew uninstall script manually for safety"
    fi
  fi

  log_ok "Uninstall complete (Xcode/CLT untouched)"
  log_info "Dotfiles repo remains at $DOTFILES"
}

main "$@"
