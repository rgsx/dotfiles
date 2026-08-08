#!/usr/bin/env bash
# Symlink manifest for dotfiles deployment.

SYMLINKS=(
  "$HOME/.config:$DOTFILES/.config"
  "$HOME/.zshrc:$HOME/.config/zsh/zshrc"
  "$HOME/.zshenv:$HOME/.config/zsh/zshenv"
  "$HOME/.ssh:$HOME/.config/ssh"
  "$HOME/.gitconfig:$HOME/.config/git/gitconfig"
)

OPTIONAL_SYMLINKS=(
  "$HOME/Development:$HOME/.dev"
)

backup_path() {
  local path="$1"
  local base
  base="$(basename "$path")"
  if [[ "$path" == "$HOME/.config" ]]; then
    base="config"
  fi
  echo "$BACKUP_DIR/$(echo "$path" | tr '/' '_')"
}

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    ensure_dir "$BACKUP_DIR"
    local dest
    dest="$(backup_path "$path")"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] backup $path -> $dest"
      return 0
    fi
    if [[ -L "$path" ]]; then
      cp -P "$path" "$dest.link" 2>/dev/null || true
    elif [[ -d "$path" ]]; then
      cp -R "$path" "$dest" 2>/dev/null || true
    else
      cp "$path" "$dest" 2>/dev/null || true
    fi
    log_info "Backed up existing $path"
  fi
}

link_path() {
  local link="$1"
  local target="$2"

  if [[ -L "$link" && "$(readlink "$link")" == "$target" ]]; then
    log_ok "Already linked: $link"
    return 0
  fi

  if [[ -e "$link" || -L "$link" ]]; then
    backup_if_exists "$link"
    run_cmd rm -rf "$link"
  fi

  ensure_dir "$(dirname "$link")"
  run_cmd ln -sfn "$target" "$link"
  log_ok "Linked $link -> $target"
}

unlink_path() {
  local link="$1"
  if [[ -L "$link" ]]; then
    run_cmd rm "$link"
    log_ok "Removed symlink $link"
  fi
}

apply_symlinks() {
  local entry link target
  for entry in "${SYMLINKS[@]}"; do
    link="${entry%%:*}"
    target="${entry#*:}"
    link_path "$link" "$target"
  done
}

apply_optional_symlinks() {
  if [[ "$SKIP_INTERACTIVE" -eq 1 ]]; then
    log_info "Skipping optional ~/Development symlink (use interactive bootstrap to enable)"
    return 0
  fi
  if confirm "Link ~/Development -> ~/.dev?"; then
    local entry link target
    for entry in "${OPTIONAL_SYMLINKS[@]}"; do
      link="${entry%%:*}"
      target="${entry#*:}"
      ensure_dir "$HOME/.dev"
      link_path "$link" "$target"
    done
  fi
}

remove_symlinks() {
  local entry link
  for entry in "${SYMLINKS[@]}"; do
    link="${entry%%:*}"
    unlink_path "$link"
  done
  for entry in "${OPTIONAL_SYMLINKS[@]}"; do
    link="${entry%%:*}"
    unlink_path "$link"
  done
}

restore_backups() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log_info "No backups to restore"
    return 0
  fi
  log_info "Backups stored in $BACKUP_DIR — restore manually if needed"
}

set_ssh_profile() {
  local profile="$1"
  local config="$DOTFILES/.config/ssh/config"

  if [[ ! -f "$config" ]]; then
    log_error "SSH config not found at $config"
    return 1
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] Set SSH profile to $profile"
    return 0
  fi

  sed -i '' \
    -e 's/^Include ~\/.ssh\/macbook_air\/macbook_air_config$/#Include ~\/.ssh\/macbook_air\/macbook_air_config/' \
    -e 's/^Include ~\/.ssh\/macbook_pro\/macbook_pro_config$/#Include ~\/.ssh\/macbook_pro\/macbook_pro_config/' \
    "$config"

  sed -i '' "s|^#Include ~/.ssh/${profile}/${profile}_config$|Include ~/.ssh/${profile}/${profile}_config|" "$config"

  log_ok "SSH profile set to $profile"
}

prompt_ssh_profile() {
  local profile="${SSH_PROFILE:-}"
  if [[ -n "$profile" ]]; then
    echo "$profile"
    return 0
  fi
  if [[ "$SKIP_INTERACTIVE" -eq 1 ]]; then
    echo "macbook_air"
    return 0
  fi
  echo "Select machine profile:" >&2
  echo "  1) macbook_air" >&2
  echo "  2) macbook_pro" >&2
  read -r -p "Choice [1]: " choice
  case "${choice:-1}" in
    2) echo "macbook_pro" ;;
    *) echo "macbook_air" ;;
  esac
}
