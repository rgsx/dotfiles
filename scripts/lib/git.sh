#!/usr/bin/env bash
# Global git configuration helpers.

GIT_GLOBAL_IGNORE="$HOME/.config/git/gitignore"

configure_git_global() {
  local excludesfile

  if [[ ! -f "$HOME/.gitconfig" ]]; then
    log_warn "~/.gitconfig not linked — run symlink phase first"
    return 1
  fi

  if [[ ! -f "$GIT_GLOBAL_IGNORE" ]]; then
    log_error "Global gitignore missing at $GIT_GLOBAL_IGNORE"
    return 1
  fi

  excludesfile="$(git config --global core.excludesfile 2>/dev/null || true)"
  if [[ -z "$excludesfile" ]]; then
    run_step "Setting global gitignore" \
      git config --global core.excludesfile "$GIT_GLOBAL_IGNORE"
  elif [[ "$(expand_tilde "$excludesfile")" != "$GIT_GLOBAL_IGNORE" ]]; then
    log_warn "core.excludesfile is '$excludesfile' — expected '$GIT_GLOBAL_IGNORE'"
    if confirm "Update core.excludesfile to dotfiles gitignore?"; then
      run_step "Updating global gitignore path" \
        git config --global core.excludesfile "$GIT_GLOBAL_IGNORE"
    fi
  else
    log_ok "Global gitignore already configured"
  fi

  if ! git config --global --get-all safe.directory 2>/dev/null | grep -Fxq "$DOTFILES"; then
    run_step "Adding dotfiles to safe.directory" \
      git config --global --add safe.directory "$DOTFILES"
  else
    log_ok "safe.directory already includes dotfiles"
  fi

  return 0
}

expand_tilde() {
  local path="$1"
  path="${path/#\~/$HOME}"
  echo "$path"
}

verify_git_global_ignore() {
  local excludesfile resolved

  excludesfile="$(git config --global core.excludesfile 2>/dev/null || true)"
  if [[ -z "$excludesfile" ]]; then
    log_error "core.excludesfile not set"
    return 1
  fi

  resolved="$(expand_tilde "$excludesfile")"
  if [[ ! -f "$resolved" ]]; then
    log_error "Global gitignore file not found: $resolved"
    return 1
  fi

  log_ok "Global gitignore active: $resolved"
  return 0
}

# Quick sanity check: a known pattern from the global file should be ignored everywhere.
test_git_global_ignore() {
  local tmpdir testfile
  tmpdir="$(mktemp -d)"
  testfile="$tmpdir/.DS_Store"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] test global gitignore in $tmpdir"
    rm -rf "$tmpdir"
    return 0
  fi

  git -C "$tmpdir" init -q
  touch "$testfile"
  if git -C "$tmpdir" status --porcelain | grep -q '\.DS_Store'; then
    log_warn "Global gitignore may not be applied (.DS_Store not ignored)"
    rm -rf "$tmpdir"
    return 1
  fi

  log_ok "Global gitignore applies to new repos"
  rm -rf "$tmpdir"
  return 0
}
