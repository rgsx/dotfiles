#!/usr/bin/env bash
# Prerequisite and post-phase verification checks.

check_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

check_apple_silicon() {
  [[ "$(uname -m)" == "arm64" ]]
}

check_xcode_clt() {
  xcode-select -p >/dev/null 2>&1
}

check_git() {
  command_exists git
}

check_homebrew() {
  command_exists brew
}

check_symlinks() {
  local link target
  # shellcheck source=scripts/lib/symlinks.sh
  source "$(dirname "${BASH_SOURCE[0]}")/symlinks.sh"
  for entry in "${SYMLINKS[@]}"; do
    link="${entry%%:*}"
    target="${entry#*:}"
    if [[ ! -L "$link" ]]; then
      return 1
    fi
    if [[ "$(readlink "$link")" != "$target" ]]; then
      return 1
    fi
  done
  return 0
}

check_brewfile_packages() {
  local brewfile="$HOME/.config/homebrew/brewfile"
  [[ -f "$brewfile" ]] || return 1
  load_homebrew_path
  command_exists brew || return 1
  brew bundle check --file="$brewfile" >/dev/null 2>&1
}

check_volta() {
  load_volta_path
  command_exists volta
}

check_node() {
  load_volta_path
  command_exists node
}

check_neovim() {
  command_exists nvim
}

check_ssh_config() {
  [[ -f "$HOME/.ssh/config" ]]
}

check_ssh_profile_active() {
  local profile="${1:-}"
  [[ -n "$profile" ]] || return 1
  grep -q "^Include ~/.ssh/${profile}/${profile}_config" "$HOME/.ssh/config"
}

# Phase 0: prerequisites
phase0_can_proceed() {
  check_macos || { log_error "macOS required"; return 1; }
  log_ok "Running on macOS"
  if ! check_apple_silicon; then
    log_warn "Not Apple Silicon — Homebrew path may differ from /opt/homebrew"
  fi
  [[ -f "$DOTFILES/scripts/bootstrap.sh" ]] || {
    log_error "scripts/bootstrap.sh not found — clone the full dotfiles repo first"
    return 1
  }
  return 0
}

phase0_verify() {
  check_xcode_clt || abort_phase 0 "Xcode Command Line Tools not installed"
  check_git || abort_phase 0 "git not available (install Xcode CLT)"
  pass_phase 0
}

# Phase 1: symlinks
phase1_can_proceed() {
  [[ -d "$DOTFILES/.config" ]] || { log_error "Missing $DOTFILES/.config"; return 1; }
  return 0
}

phase1_verify() {
  check_symlinks || abort_phase 1 "Symlinks not correctly applied"
  check_ssh_config || abort_phase 1 "SSH config missing at ~/.ssh/config"
  # shellcheck source=scripts/lib/git.sh
  source "$(dirname "${BASH_SOURCE[0]}")/git.sh"
  verify_git_global_ignore || abort_phase 1 "Global gitignore not configured"
  pass_phase 1
}

# Phase 2: Homebrew
phase2_can_proceed() {
  check_xcode_clt || { log_error "Install Xcode CLT first: xcode-select --install"; return 1; }
  check_git || { log_error "git required"; return 1; }
  return 0
}

phase2_verify() {
  check_homebrew || abort_phase 2 "Homebrew not installed"
  pass_phase 2
}

# Phase 3: brew bundle
phase3_can_proceed() {
  check_homebrew || { log_error "Homebrew required"; return 1; }
  [[ -f "$HOME/.config/homebrew/brewfile" ]] || { log_error "Brewfile not found at ~/.config/homebrew/brewfile"; return 1; }
  return 0
}

phase3_verify() {
  load_homebrew_path
  if ! check_brewfile_packages; then
    log_warn "Some Brewfile packages may be missing — run: brew bundle install"
    if [[ "$SKIP_INTERACTIVE" -eq 0 ]]; then
      confirm "Continue anyway?" || abort_phase 3 "Brew bundle incomplete"
    fi
  fi
  pass_phase 3
}

# Phase 4: post-brew
phase4_can_proceed() {
  load_homebrew_path
  check_homebrew || { log_error "Homebrew required"; return 1; }
  return 0
}

phase4_verify() {
  load_homebrew_path
  if command_exists git-lfs; then
    git lfs version >/dev/null 2>&1 || abort_phase 4 "git-lfs not working"
  else
    log_warn "git-lfs not installed yet"
  fi
  pass_phase 4
}

# Phase 5: toolchains
phase5_can_proceed() {
  load_homebrew_path
  return 0
}

phase5_verify() {
  load_volta_path
  if check_volta; then
    check_node || log_warn "Node not pinned yet — run volta install in $DOTFILES"
  else
    log_warn "Volta not installed — skipping node verification"
  fi
  pass_phase 5
}

# Phase 6: shell/editor bootstrap
phase6_can_proceed() {
  return 0
}

phase6_verify() {
  if check_neovim; then
    log_ok "Neovim available"
  else
    log_warn "Neovim not found — lazy sync skipped"
  fi
  pass_phase 6
}

# Phase 7: SSH keys + manual checklist
phase7_can_proceed() {
  check_ssh_config || { log_error "SSH config required (~/.ssh symlink)"; return 1; }
  return 0
}

phase7_verify() {
  pass_phase 7
}
