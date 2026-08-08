#!/usr/bin/env bash
# Symlink Cursor User settings to dotfiles.

CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
CURSOR_SETTINGS_LINK="$CURSOR_USER_DIR/settings.json"
CURSOR_SETTINGS_TARGET="$DOTFILES/.config/cursor/user/settings.json"
CURSOR_SETTINGS_BACKUP="$BACKUP_DIR/cursor-user-settings.json"

link_cursor_code_cli() {
  local cursor_bin="/opt/homebrew/bin/cursor"
  local code_bin="/opt/homebrew/bin/code"

  if [[ ! -x "$cursor_bin" && -x "/Applications/Cursor.app/Contents/Resources/app/bin/code" ]]; then
    cursor_bin="/Applications/Cursor.app/Contents/Resources/app/bin/code"
  fi

  if [[ ! -x "$cursor_bin" ]] && ! command_exists cursor; then
    log_warn "Cursor CLI not found — skipping code symlink"
    return 0
  fi

  if [[ -L "$code_bin" && "$(readlink "$code_bin")" == "$cursor_bin" ]]; then
    log_ok "Already linked: $code_bin -> $cursor_bin"
    return 0
  fi

  if [[ -e "$code_bin" && ! -L "$code_bin" ]]; then
    log_warn "$code_bin exists and is not a symlink — skipping"
    return 0
  fi

  ensure_dir "/opt/homebrew/bin"
  run_cmd ln -sfn "$cursor_bin" "$code_bin"
  log_ok "Linked $code_bin -> $cursor_bin"
}

cursor_settings_exists() {
  [[ -d "$CURSOR_USER_DIR" ]]
}

import_cursor_settings() {
  local source="$CURSOR_SETTINGS_LINK"

  if [[ -L "$source" ]]; then
    source="$(readlink "$source")"
    log_info "Reading settings from symlink target: $source"
  fi

  if [[ ! -f "$source" ]]; then
    log_error "No Cursor settings found at $CURSOR_SETTINGS_LINK"
    log_info "Install Cursor and configure settings first, or create $CURSOR_SETTINGS_TARGET manually"
    return 1
  fi

  ensure_dir "$(dirname "$CURSOR_SETTINGS_TARGET")"
  run_cmd cp "$source" "$CURSOR_SETTINGS_TARGET"
  log_ok "Imported settings to $CURSOR_SETTINGS_TARGET"
}

link_cursor_settings() {
  if [[ ! -f "$CURSOR_SETTINGS_TARGET" ]]; then
    log_warn "Repo settings missing at $CURSOR_SETTINGS_TARGET"
    if [[ -f "$CURSOR_SETTINGS_LINK" && ! -L "$CURSOR_SETTINGS_LINK" ]]; then
      log_info "Importing current Cursor settings into repo first..."
      import_cursor_settings
    elif ! confirm "Create empty settings file in repo and link?"; then
      return 1
    else
      ensure_dir "$(dirname "$CURSOR_SETTINGS_TARGET")"
      run_cmd echo '{}' > "$CURSOR_SETTINGS_TARGET"
    fi
  fi

  if [[ -L "$CURSOR_SETTINGS_LINK" && "$(readlink "$CURSOR_SETTINGS_LINK")" == "$CURSOR_SETTINGS_TARGET" ]]; then
    log_ok "Already linked: $CURSOR_SETTINGS_LINK"
    return 0
  fi

  if [[ -e "$CURSOR_SETTINGS_LINK" || -L "$CURSOR_SETTINGS_LINK" ]]; then
    ensure_dir "$BACKUP_DIR"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] backup $CURSOR_SETTINGS_LINK -> $CURSOR_SETTINGS_BACKUP"
    else
      cp "$CURSOR_SETTINGS_LINK" "$CURSOR_SETTINGS_BACKUP" 2>/dev/null || true
      log_info "Backed up to $CURSOR_SETTINGS_BACKUP"
    fi
    run_cmd rm -f "$CURSOR_SETTINGS_LINK"
  fi

  ensure_dir "$CURSOR_USER_DIR"
  run_cmd ln -sfn "$CURSOR_SETTINGS_TARGET" "$CURSOR_SETTINGS_LINK"
  log_ok "Linked $CURSOR_SETTINGS_LINK -> $CURSOR_SETTINGS_TARGET"
  log_warn "Restart Cursor for settings to reload"
}

unlink_cursor_settings() {
  if [[ ! -L "$CURSOR_SETTINGS_LINK" ]]; then
    log_info "Cursor settings is not a symlink — nothing to unlink"
    return 0
  fi

  run_cmd rm -f "$CURSOR_SETTINGS_LINK"

  if [[ -f "$CURSOR_SETTINGS_BACKUP" ]]; then
    if confirm "Restore settings from backup?"; then
      run_cmd cp "$CURSOR_SETTINGS_BACKUP" "$CURSOR_SETTINGS_LINK"
      log_ok "Restored settings from backup"
    else
      run_cmd cp "$CURSOR_SETTINGS_TARGET" "$CURSOR_SETTINGS_LINK"
      log_ok "Restored settings by copying repo file (no longer symlinked)"
    fi
  elif [[ -f "$CURSOR_SETTINGS_TARGET" ]]; then
    run_cmd cp "$CURSOR_SETTINGS_TARGET" "$CURSOR_SETTINGS_LINK"
    log_ok "Restored settings by copying repo file (no longer symlinked)"
  fi
}

verify_cursor_settings_link() {
  [[ -L "$CURSOR_SETTINGS_LINK" ]] || return 1
  [[ "$(readlink "$CURSOR_SETTINGS_LINK")" == "$CURSOR_SETTINGS_TARGET" ]] || return 1
  [[ -f "$CURSOR_SETTINGS_TARGET" ]] || return 1
  return 0
}

status_cursor_settings() {
  echo "Repo:   $CURSOR_SETTINGS_TARGET"
  echo "Cursor: $CURSOR_SETTINGS_LINK"
  if [[ -L "$CURSOR_SETTINGS_LINK" ]]; then
    echo "State:  symlink -> $(readlink "$CURSOR_SETTINGS_LINK")"
  elif [[ -f "$CURSOR_SETTINGS_LINK" ]]; then
    echo "State:  regular file (not linked)"
  else
    echo "State:  missing"
  fi
}
