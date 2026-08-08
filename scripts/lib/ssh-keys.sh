#!/usr/bin/env bash
# SSH key generation from machine profile config.

SSH_KEYS_ALL=0
SSH_KEYS_FIX_PERMS=0
SSH_KEYS_TEST=0
SSH_KEYS_NO_PASSPHRASE=0
SSH_PROFILE_OVERRIDE=""

HOST_KEY_COMMENTS=(
  "github.com:jrgsx@icloud.com"
  "gtec:robert@gtec"
  "gnp-gitlab:jose.gonzalezsanchez@proveedoresgnp.mx"
  "vps:robert@vps"
  "vps-root:robert@vps"
)

expand_path() {
  local path="$1"
  path="${path/#\~/$HOME}"
  echo "$path"
}

resolve_active_profile_config() {
  local ssh_config="$HOME/.ssh/config"
  local include_line profile_dir

  if [[ -n "$SSH_PROFILE_OVERRIDE" ]]; then
    echo "$HOME/.ssh/${SSH_PROFILE_OVERRIDE}/${SSH_PROFILE_OVERRIDE}_config"
    return 0
  fi

  include_line="$(grep -E '^Include ' "$ssh_config" | head -1 | awk '{print $2}')"
  if [[ -z "$include_line" ]]; then
    log_error "No active Include line in $ssh_config"
    return 1
  fi
  echo "$(expand_path "$include_line")"
}

key_comment_for_host() {
  local host="$1"
  local entry key value
  for entry in "${HOST_KEY_COMMENTS[@]}"; do
    key="${entry%%:*}"
    value="${entry#*:}"
    if [[ "$host" == "$key" ]]; then
      echo "$value"
      return 0
    fi
  done
  echo "$(whoami)@$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
}

parse_identity_entries() {
  local config_file="$1"
  local host="" identity="" comment=""
  local -a entries=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue

    if [[ "$line" =~ ^Host[[:space:]]+(.*)$ ]]; then
      host="${BASH_REMATCH[1]}"
      continue
    fi

    if [[ "$line" =~ ^IdentityFile[[:space:]]+(.*)$ ]]; then
      identity="$(expand_path "${BASH_REMATCH[1]}")"
      comment="$(key_comment_for_host "$host")"
      entries+=("${host}|${identity}|${comment}")
    fi
  done < "$config_file"

  printf '%s\n' "${entries[@]}"
}

dedupe_identity_paths() {
  awk -F'|' '!seen[$2]++ { print }'
}

fix_key_permissions() {
  local key_path="$1"
  if [[ -f "$key_path" ]]; then
    run_cmd chmod 600 "$key_path"
    [[ -f "${key_path}.pub" ]] && run_cmd chmod 644 "${key_path}.pub"
    log_ok "Permissions fixed: $key_path"
  fi
}

add_key_to_agent() {
  local key_path="$1"
  if [[ -f "$key_path" ]]; then
    run_cmd ssh-add --apple-use-keychain "$key_path" 2>/dev/null || run_cmd ssh-add "$key_path" 2>/dev/null || true
  fi
}

generate_key() {
  local key_path="$1"
  local comment="$2"
  local passphrase_args=(-N "")

  ensure_dir "$(dirname "$key_path")"

  if [[ "$SSH_KEYS_NO_PASSPHRASE" -eq 0 && "$SKIP_INTERACTIVE" -eq 0 ]]; then
    passphrase_args=()
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] ssh-keygen -t ed25519 -f $key_path -C $comment"
    return 0
  fi

  ssh-keygen -t ed25519 -f "$key_path" -C "$comment" "${passphrase_args[@]}"
}

process_identity_entry() {
  local host="$1"
  local key_path="$2"
  local comment="$3"

  if [[ -f "$key_path" ]]; then
    log_ok "Key exists: $key_path ($host)"
    fix_key_permissions "$key_path"
    add_key_to_agent "$key_path"
    return 0
  fi

  if [[ "$SSH_KEYS_FIX_PERMS" -eq 1 ]]; then
    return 0
  fi

  if [[ "$SSH_KEYS_ALL" -eq 0 && "$SKIP_INTERACTIVE" -eq 0 ]]; then
    confirm "Create key for ${host} at ${key_path}?" || return 0
  fi

  log_info "Creating key for ${host}: ${key_path}"
  generate_key "$key_path" "$comment"
  fix_key_permissions "$key_path"
  add_key_to_agent "$key_path"
}

print_public_key_summary() {
  local config_file="$1"
  local entries host key_path comment

  echo
  echo "Add these public keys to their services:"
  entries="$(parse_identity_entries "$config_file" | dedupe_identity_paths)"
  while IFS='|' read -r host key_path comment; do
    [[ -z "$key_path" ]] && continue
    if [[ -f "${key_path}.pub" ]]; then
      echo "  ${host}"
      echo "    private: ${key_path}"
      echo "    public:  ${key_path}.pub"
      echo "    key:     $(tr -d '\n' < "${key_path}.pub" | cut -c1-60)..."
      echo
    else
      echo "  ${host} → missing ${key_path}.pub"
    fi
  done <<< "$entries"
}

test_ssh_connections() {
  local host
  for host in github.com gnp-gitlab gtec; do
    if grep -q "^Host ${host}" "$(resolve_active_profile_config)" 2>/dev/null; then
      log_info "Testing ssh -T git@${host}..."
      ssh -T "git@${host}" 2>&1 || true
    fi
  done
}

run_ssh_keys() {
  local config_file entries line host key_path comment

  config_file="$(resolve_active_profile_config)" || return 1
  [[ -f "$config_file" ]] || { log_error "Profile config not found: $config_file"; return 1; }

  log_info "Using SSH profile config: $config_file"
  entries="$(parse_identity_entries "$config_file" | dedupe_identity_paths)"

  while IFS='|' read -r host key_path comment; do
    [[ -z "$key_path" ]] && continue
    process_identity_entry "$host" "$key_path" "$comment"
  done <<< "$entries"

  if [[ "$SSH_KEYS_FIX_PERMS" -eq 0 ]]; then
    print_public_key_summary "$config_file"
  fi

  if [[ "$SSH_KEYS_TEST" -eq 1 ]]; then
    test_ssh_connections
  fi
}

parse_ssh_keys_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)
        SSH_KEYS_ALL=1
        shift
        ;;
      --fix-perms)
        SSH_KEYS_FIX_PERMS=1
        shift
        ;;
      --test)
        SSH_KEYS_TEST=1
        shift
        ;;
      --no-passphrase)
        SSH_KEYS_NO_PASSPHRASE=1
        shift
        ;;
      --profile)
        SSH_PROFILE_OVERRIDE="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
}

warn_tracked_private_keys() {
  local tracked
  if ! command_exists git; then
    return 0
  fi
  tracked="$(git -C "$DOTFILES" ls-files '.config/ssh/*' 2>/dev/null | grep -v '\.pub$' | grep -v '_config$' | grep -v 'config$' | grep -v 'known_hosts' || true)"
  if [[ -n "$tracked" ]]; then
    log_warn "Private SSH keys are tracked in git — remove with: git rm --cached <file>"
    echo "$tracked"
  fi
}
