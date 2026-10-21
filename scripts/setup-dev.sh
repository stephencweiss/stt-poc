#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
case "${1:-}" in
    '') python3 scripts/tooling.py verify ;;
    --install-tools) python3 scripts/tooling.py install ;;
    --hooks) python3 scripts/tooling.py verify; python3 scripts/tooling.py hooks ;;
    *) echo 'Usage: ./scripts/setup-dev.sh [--install-tools|--hooks]' >&2; exit 2 ;;
esac
