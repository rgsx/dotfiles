#!/usr/bin/env bash
# Install Cursor extensions via the Cursor CLI (not brew bundle vscode entries).

CURSOR_EXTENSIONS=(
  "catppuccin.catppuccin-vsc"
  "catppuccin.catppuccin-vsc-icons"
  "catppuccin.catppuccin-vsc-pack"
)

# Bundled with Cursor — do not install via CLI
CURSOR_BUNDLED_EXTENSIONS=(
  "anysphere.remote-containers"
  "anysphere.remote-ssh"
)

cursor_cli() {
  if command_exists cursor; then
    command cursor
    return 0
  fi
  if [[ -x "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" ]]; then
    echo "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
    return 0
  fi
  return 1
}

install_cursor_extensions() {
  local cli ext installed

  cli="$(cursor_cli)" || {
    log_error "Cursor CLI not found — install the cursor and cursor-cli casks first"
    return 1
  }

  log_info "Using Cursor CLI: $cli"

  for ext in "${CURSOR_BUNDLED_EXTENSIONS[@]}"; do
    if "$cli" --list-extensions 2>/dev/null | grep -qi "^${ext}$"; then
      log_ok "Bundled extension present: $ext"
    else
      log_warn "Expected bundled extension missing: $ext (reinstall Cursor if needed)"
    fi
  done

  for ext in "${CURSOR_EXTENSIONS[@]}"; do
    if "$cli" --list-extensions 2>/dev/null | grep -qi "^${ext}$"; then
      log_ok "Already installed: $ext"
      continue
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] $cli --install-extension $ext"
      continue
    fi

    log_info "Installing $ext..."
    if "$cli" --install-extension "$ext"; then
      log_ok "Installed $ext"
    else
      log_warn "Failed to install $ext"
    fi
  done
}
