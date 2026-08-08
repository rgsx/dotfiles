#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/cursor-extensions.sh
source "$SCRIPT_DIR/lib/cursor-extensions.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Install Cursor theme extensions via the Cursor CLI.

Does NOT install anysphere.remote-* extensions — those ship with Cursor.

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
  install_cursor_extensions
}

main "$@"
