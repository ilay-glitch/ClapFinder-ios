#!/usr/bin/env bash
# scripts/lint/no-hardcoded-strings.sh
# Flags user-visible string literals in SwiftUI components that bypass Localizable.strings.
# Suppress per-line with: // allow-hardcoded-string until: pr-N
#
# Caught patterns: Text("..."), Button("..."), Label("..."), .navigationTitle("..."), .alert("...")
#
# Usage: bash scripts/lint/no-hardcoded-strings.sh [repo-root]

REPO_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

FAIL=0
VIOLATIONS=0

while IFS= read -r -d '' file; do
    # Exempt: tests, previews, debug, localizable files
    if [[ "$file" == *"/Tests/"* ]]; then continue; fi
    if [[ "$file" == *"Preview"* ]]; then continue; fi
    if [[ "$file" == *"/Debug/"* ]]; then continue; fi
    if [[ "$file" == *"Localizable"* ]]; then continue; fi

    while IFS= read -r match; do
        lineno="${match%%:*}"
        content="${match#*:}"
        if echo "$content" | grep -q "allow-hardcoded-string"; then continue; fi
        echo "  ${file#"$REPO_ROOT"/}:$lineno — hardcoded user-visible string"
        echo "    $content"
        VIOLATIONS=$((VIOLATIONS + 1))
        FAIL=1
    done < <(grep -nE '(Text|Button|Label)\("[^"]+"\)|(\.navigationTitle|\.alert)\("[^"]+"\)' "$file" 2>/dev/null || true)
done < <(find "$REPO_ROOT" -name "*.swift" -not -path "*/.build/*" -print0)

if [ $FAIL -eq 1 ]; then
    echo "  ❌ no-hardcoded-strings: $VIOLATIONS violation(s). Use LocalizedStringKey or suppress with // allow-hardcoded-string until: pr-N"
    exit 1
fi

echo "  ✓ no-hardcoded-strings: 0 violations"
