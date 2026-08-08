#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/checks.sh
source "$SCRIPT_DIR/lib/checks.sh"
# shellcheck source=scripts/lib/symlinks.sh
source "$SCRIPT_DIR/lib/symlinks.sh"
# shellcheck source=scripts/lib/ssh-keys.sh
source "$SCRIPT_DIR/lib/ssh-keys.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Idempotent sync: symlinks, Homebrew packages, toolchains, and SSH permissions.

Options:
  --dry-run           Show actions without executing
  --skip-interactive  Accept defaults without prompts
  -h, --help          Show this help
EOF
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  parse_common_flags "$@"
  phase_header "Update dotfiles environment"

  log_info "Dotfiles root: $DOTFILES"

  phase_header "Symlinks"
  apply_symlinks

  phase_header "Homebrew"
  load_homebrew_path
  if check_homebrew; then
    run_step "Updating Homebrew" brew update
    run_step "Installing Brewfile packages" \
      brew bundle install --file="$HOME/.config/homebrew/brewfile"
  else
    log_warn "Homebrew not installed — run bootstrap.sh first"
  fi

  phase_header "Apps"
  # shellcheck source=scripts/lib/cursor.sh
  source "$SCRIPT_DIR/lib/cursor.sh"
  if cursor_settings_exists && [[ -f "$CURSOR_SETTINGS_TARGET" ]]; then
    local prev_skip="$SKIP_INTERACTIVE"
    SKIP_INTERACTIVE=1
    link_cursor_settings || true
    SKIP_INTERACTIVE="$prev_skip"
  fi
  link_cursor_code_cli

  # shellcheck source=scripts/lib/cursor-extensions.sh
  source "$SCRIPT_DIR/lib/cursor-extensions.sh"
  install_cursor_extensions || true

  phase_header "Git global config"
  # shellcheck source=scripts/lib/git.sh
  source "$SCRIPT_DIR/lib/git.sh"
  configure_git_global
  test_git_global_ignore

  phase_header "Post-brew"
  if command_exists git-lfs; then
    run_step "git-lfs install" git lfs install
  fi
  if command_exists corepack; then
    run_step "corepack enable" corepack enable
  fi

  phase_header "Toolchains"
  load_volta_path
  if command_exists volta && [[ -f "$DOTFILES/package.json" ]]; then
    run_step "volta install" volta install
  fi

  phase_header "SSH permissions"
  SSH_KEYS_FIX_PERMS=1
  run_ssh_keys

  phase_header "Shell and editor"
  if command_exists zsh; then
    run_step "Zinit update" zsh -i -c 'zinit self-update' || true
  fi
  if command_exists nvim; then
    run_step "Neovim plugin sync" nvim --headless "+Lazy! sync" +qa || true
  fi

  if check_homebrew; then
    echo
    log_info "Outdated packages:"
    brew outdated 2>/dev/null || log_warn "Could not check outdated packages"
  fi

  log_ok "Update complete"
}

main "$@"
