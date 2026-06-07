#!/usr/bin/env bash
# scripts/lint/all.sh
# Runs all lint rules. CI and pre-PR gate.
# Usage: bash scripts/lint/all.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FAIL=0

echo "▶ SwiftLint..."
if ! swiftlint lint --strict --config "$REPO_ROOT/.swiftlint.yml" --path "$REPO_ROOT"; then
    FAIL=1
fi

echo ""
echo "▶ no-hardcoded-hex..."
if ! bash "$SCRIPT_DIR/no-hardcoded-hex.sh" "$REPO_ROOT"; then
    FAIL=1
fi

echo ""
echo "▶ no-hardcoded-strings..."
if ! bash "$SCRIPT_DIR/no-hardcoded-strings.sh" "$REPO_ROOT"; then
    FAIL=1
fi

echo ""
if [ $FAIL -eq 1 ]; then
    echo "❌ Lint failed — fix violations before opening PR."
    exit 1
fi

echo "✅ All lints passed."
