#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/cursor.sh
source "$SCRIPT_DIR/lib/cursor.sh"

ACTION="link"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [command]

Symlink Cursor User settings.json to dotfiles.

Commands:
  link      Link Cursor settings to ~/.config/cursor/user/settings.json (default)
  unlink    Remove symlink and restore a regular settings file
  import    Copy current Cursor settings into the repo (does not symlink)
  status    Show link state

Options:
  --dry-run           Show actions without executing
  --skip-interactive  Accept defaults without prompts
  -h, --help          Show this help

Examples:
  $(basename "$0") import && $(basename "$0") link
  $(basename "$0") status
  $(basename "$0") --dry-run link
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      link | unlink | import | status)
        ACTION="$1"
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --skip-interactive)
        SKIP_INTERACTIVE=1
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  if ! cursor_settings_exists; then
    log_error "Cursor User directory not found: $CURSOR_USER_DIR"
    log_info "Install Cursor first, then re-run this script"
    exit 1
  fi

  case "$ACTION" in
    link)
      link_cursor_settings
      if [[ "$DRY_RUN" -eq 1 ]]; then
        log_warn "Skipping verification in dry-run mode"
      elif verify_cursor_settings_link; then
        log_ok "Cursor settings linked and verified"
      else
        log_error "Link verification failed"
        exit 1
      fi
      ;;
    unlink)
      unlink_cursor_settings
      ;;
    import)
      import_cursor_settings
      ;;
    status)
      status_cursor_settings
      ;;
  esac
}

main "$@"
