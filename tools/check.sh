#!/usr/bin/env bash
# Checks every script under src/ with luau-lsp. By default it prints only the
# errors that stop a script from loading (syntax errors). Pass --all to see
# every lint and type warning (noisy without Roblox definitions).
set -euo pipefail
cd "$(dirname "$0")/.."

out=$(luau-lsp analyze --platform=standard src 2>&1 || true)
if [[ "${1:-}" == "--all" ]]; then
	echo "$out"
	exit 0
fi

severe=$(echo "$out" | grep -E 'SyntaxError' || true)
if [[ -n "$severe" ]]; then
	echo "$severe"
	exit 1
fi
echo "No load-breaking errors."
