#!/bin/bash

echo "🔍 Searching for Flutter installation..."

# Common Flutter locations
POSSIBLE_PATHS=(
    "$HOME/flutter"
    "$HOME/development/flutter"
    "$HOME/Developer/flutter"
    "$HOME/sdk/flutter"
    "$HOME/tools/flutter"
    "/usr/local/flutter"
    "/opt/flutter"
    "/Applications/flutter"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path/bin/flutter" ]; then
        echo "✅ Found Flutter at: $path"
        echo "Flutter version:"
        "$path/bin/flutter" --version
        echo ""
        echo "To use this Flutter installation, run:"
        echo "export PATH=\"$path/bin:\$PATH\""
        exit 0
    fi
done

echo "❌ Flutter not found in common locations."
echo ""
echo "Try running these commands to find Flutter:"
echo "1. which flutter"
echo "2. find ~ -name 'flutter' -type d 2>/dev/null | grep -E 'flutter$'"
echo ""
echo "Or check if you installed Flutter via Homebrew:"
echo "brew list flutter"