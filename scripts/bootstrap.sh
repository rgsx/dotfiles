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

Bootstrap a fresh macOS development environment from these dotfiles.

Options:
  --dry-run           Show actions without executing
  --skip-interactive  Accept defaults without prompts
  --profile NAME      SSH machine profile (macbook_air | macbook_pro)
  -h, --help          Show this help
EOF
}

install_xcode_clt() {
  if check_xcode_clt; then
    log_ok "Xcode Command Line Tools already installed"
    return 0
  fi
  log_info "Installing Xcode Command Line Tools (GUI prompt will appear)..."
  run_cmd xcode-select --install || true
  log_warn "Complete the CLT install dialog, then re-run bootstrap"
  exit 1
}

install_homebrew() {
  if check_homebrew; then
    log_ok "Homebrew already installed"
    load_homebrew_path
    return 0
  fi
  log_info "Installing Homebrew..."
  run_cmd /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_homebrew_path
  if ! check_homebrew; then
    log_error "Homebrew installed but not on PATH in this shell"
    log_info "Run: eval \"\$(/opt/homebrew/bin/brew shellenv)\" && $0"
    exit 1
  fi
}

run_brew_bundle() {
  local brewfile="$HOME/.config/homebrew/brewfile"
  run_step "Installing Brewfile packages" brew bundle install --file="$brewfile"
}

run_post_brew_setup() {
  load_homebrew_path

  if command_exists git-lfs; then
    run_step "Initializing git-lfs" git lfs install
  else
    log_warn "git-lfs not found — skipping"
  fi

  if [[ -d /opt/homebrew/opt/openjdk/libexec/openjdk.jdk ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] sudo ln -sfn openjdk.jdk -> /Library/Java/JavaVirtualMachines/"
    else
      run_step "Linking OpenJDK for macOS" \
        sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk \
        /Library/Java/JavaVirtualMachines/openjdk.jdk
    fi
  fi

  if [[ ! -f "$HOME/.gnupg/gpg-agent.conf" ]] || ! grep -q 'pinentry-program' "$HOME/.gnupg/gpg-agent.conf" 2>/dev/null; then
    ensure_dir "$HOME/.gnupg"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      if [[ -f "$HOME/.gnupg/gpg-agent.conf" ]]; then
        echo "pinentry-program /opt/homebrew/bin/pinentry-mac" >> "$HOME/.gnupg/gpg-agent.conf"
      else
        echo "pinentry-program /opt/homebrew/bin/pinentry-mac" > "$HOME/.gnupg/gpg-agent.conf"
      fi
      run_cmd chmod 600 "$HOME/.gnupg/gpg-agent.conf"
    else
      echo "[dry-run] configure pinentry-mac in gpg-agent.conf"
    fi
    log_ok "GPG agent configured for pinentry-mac"
  fi

  if command_exists corepack; then
    log_ok "corepack available"
  fi
}

run_app_setup() {
  # shellcheck source=scripts/lib/cursor.sh
  source "$SCRIPT_DIR/lib/cursor.sh"

  if cursor_settings_exists; then
    if [[ -f "$CURSOR_SETTINGS_TARGET" ]]; then
      local prev_skip="$SKIP_INTERACTIVE"
      SKIP_INTERACTIVE=1
      link_cursor_settings || log_warn "Cursor settings link skipped"
      SKIP_INTERACTIVE="$prev_skip"
    else
      log_warn "No repo Cursor settings at $CURSOR_SETTINGS_TARGET — run: ./scripts/cursor-settings.sh import"
    fi
  else
    log_warn "Cursor not installed yet — settings link skipped"
  fi

  if [[ -d "/Applications/Docker.app" ]]; then
    log_ok "Docker Desktop installed"
    log_info "Open Docker Desktop once to finish setup and enable CLI completions"
  fi

  if [[ -d "/Applications/Raycast.app" ]]; then
    log_ok "Raycast installed"
  fi

  if command_exists cursor; then
    log_ok "Cursor CLI available"
  elif [[ -x "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" ]]; then
    log_ok "Cursor CLI available"
  else
    log_warn "Cursor CLI not on PATH — cursor-cli cask may need a new shell"
  fi

  link_cursor_code_cli

  # shellcheck source=scripts/lib/cursor-extensions.sh
  source "$SCRIPT_DIR/lib/cursor-extensions.sh"
  install_cursor_extensions || log_warn "Cursor extension install had warnings"
}

run_toolchains() {
  load_homebrew_path
  load_volta_path

  if ! command_exists volta; then
    log_warn "Volta not installed — skipping JS toolchain"
    return 0
  fi

  if [[ -f "$DOTFILES/package.json" ]]; then
    run_step "Installing Volta toolchain from package.json" \
      volta install
  else
    log_warn "No package.json in $DOTFILES — skipping volta install"
  fi

  if command_exists corepack; then
    run_step "Enabling corepack" corepack enable
  fi
}

run_shell_bootstrap() {
  if command_exists zsh; then
    run_step "Bootstrapping Zinit plugins" zsh -i -c 'exit' || log_warn "Zinit bootstrap had warnings"
  fi
}

run_editor_bootstrap() {
  if command_exists nvim; then
    run_step "Syncing Neovim plugins" \
      nvim --headless "+Lazy! sync" +qa || log_warn "Neovim sync had warnings"
  else
    log_warn "Neovim not installed — skipping plugin sync"
  fi
}

print_manual_checklist() {
  phase_header "Manual steps remaining"
  cat <<EOF
  GPG:      Import your signing key from secure backup
  gh:       Run 'gh auth login' if not authenticated
  Ghostty:  Install app and Monaspace fonts manually
  Cursor:   Restart Cursor after settings link; run 'setDevFileTypes' in zsh
  Docker:   Open Docker Desktop once to complete setup
  Raycast:  Sign in and configure on first launch
EOF
}

run_phase() {
  local num="$1"
  local name="$2"
  local can_fn="$3"
  local run_fn="$4"
  local verify_fn="$5"

  phase_header "Phase ${num}: ${name}"

  if ! "$can_fn"; then
    abort_phase "$num" "Pre-checks failed — fix issues above before continuing"
  fi

  "$run_fn"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "Skipping post-checks in dry-run mode"
    pass_phase "$num"
    return 0
  fi

  if ! "$verify_fn"; then
    abort_phase "$num" "Post-checks failed"
  fi
}

phase0_run() { install_xcode_clt; }
phase1_run() {
  local profile
  profile="$(prompt_ssh_profile)"
  set_ssh_profile "$profile"
  apply_symlinks
  apply_optional_symlinks
  # shellcheck source=scripts/lib/git.sh
  source "$SCRIPT_DIR/lib/git.sh"
  configure_git_global
}
phase2_run() { install_homebrew; }
phase3_run() { run_brew_bundle; }
phase4_run() {
  run_post_brew_setup
  run_app_setup
}
phase5_run() { run_toolchains; }
phase6_run() {
  run_shell_bootstrap
  run_editor_bootstrap
}
phase7_run() {
  warn_tracked_private_keys
  if [[ "$SKIP_INTERACTIVE" -eq 1 ]]; then
    SSH_KEYS_ALL=1
  fi
  run_ssh_keys
  print_manual_checklist
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  parse_common_flags "$@"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        SSH_PROFILE="$2"
        SSH_PROFILE_OVERRIDE="$2"
        shift 2
        ;;
      --dry-run | --skip-interactive)
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  log_info "Dotfiles root: $DOTFILES"

  run_phase 0 "Prerequisites" phase0_can_proceed phase0_run phase0_verify
  run_phase 1 "Dotfiles and symlinks" phase1_can_proceed phase1_run phase1_verify
  run_phase 2 "Homebrew" phase2_can_proceed phase2_run phase2_verify
  run_phase 3 "Brew bundle" phase3_can_proceed phase3_run phase3_verify
  run_phase 4 "Post-brew setup" phase4_can_proceed phase4_run phase4_verify
  run_phase 5 "JS toolchains" phase5_can_proceed phase5_run phase5_verify
  run_phase 6 "Shell and editor" phase6_can_proceed phase6_run phase6_verify
  run_phase 7 "SSH keys and manual checklist" phase7_can_proceed phase7_run phase7_verify

  phase_header "Bootstrap complete"
  log_ok "Environment ready. Open a new terminal or run: exec zsh -l"
}

main "$@"
