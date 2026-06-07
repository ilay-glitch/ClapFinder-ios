#!/usr/bin/env bash
# scripts/lint/no-hardcoded-hex.sh
# Flags hex color literals outside ClapFinderKitDesign.
# Suppress per-line with: // allow-hardcoded-hex until: pr-N
#
# Usage: bash scripts/lint/no-hardcoded-hex.sh [repo-root]

REPO_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
EXEMPT_DIR="$REPO_ROOT/ClapFinderKit/Sources/ClapFinderKitDesign"

FAIL=0
VIOLATIONS=0

while IFS= read -r -d '' file; do
    # Exempt: design module, tests, previews, debug
    if [[ "$file" == "$EXEMPT_DIR"* ]]; then continue; fi
    if [[ "$file" == *"/Tests/"* ]]; then continue; fi
    if [[ "$file" == *"Preview"* ]]; then continue; fi
    if [[ "$file" == *"/Debug/"* ]]; then continue; fi

    while IFS= read -r match; do
        lineno="${match%%:*}"
        content="${match#*:}"
        if echo "$content" | grep -q "allow-hardcoded-hex"; then continue; fi
        echo "  ${file#"$REPO_ROOT"/}:$lineno — hardcoded hex color"
        echo "    $content"
        VIOLATIONS=$((VIOLATIONS + 1))
        FAIL=1
    done < <(grep -nE '(#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?|0x[0-9A-Fa-f]{6}|Color\(red:)' "$file" 2>/dev/null || true)
done < <(find "$REPO_ROOT" -name "*.swift" -not -path "*/.build/*" -print0)

if [ $FAIL -eq 1 ]; then
    echo "  ❌ no-hardcoded-hex: $VIOLATIONS violation(s). Move hex to ClapFinderKitDesign or suppress with // allow-hardcoded-hex until: pr-N"
    exit 1
fi

echo "  ✓ no-hardcoded-hex: 0 violations"
