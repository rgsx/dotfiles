#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/ssh-keys.sh
source "$SCRIPT_DIR/lib/ssh-keys.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Generate SSH keys from the active machine profile in ~/.ssh/config.

Options:
  --all              Create all missing keys without per-key prompts
  --fix-perms        Fix permissions on existing keys only
  --test             Test SSH connections after setup
  --no-passphrase    Generate keys without a passphrase
  --profile NAME     Override profile (macbook_air | macbook_pro)
  --dry-run          Show actions without executing
  --skip-interactive Accept defaults without prompts
  -h, --help         Show this help
EOF
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  parse_common_flags "$@"
  parse_ssh_keys_flags "$@"
  warn_tracked_private_keys
  run_ssh_keys
}

main "$@"
