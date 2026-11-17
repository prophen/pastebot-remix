#!/bin/zsh
# Install only into an empty stable location. Never replace an unknown app.
set -euo pipefail
SOURCE="${1:?Usage: ./scripts/install.sh '/path/to/signed/Clipboard Remix.app'}"
DEST="/Volumes/Expansion/pastebot-remix-build/Installed/Clipboard Remix.app"
[[ -d /Volumes/Expansion ]] || { print -u2 "Mount Expansion first."; exit 1; }
[[ ! -e "$DEST" && ! -L "$DEST" ]] || { print -u2 "Destination already exists; leaving it untouched: $DEST"; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE/Contents/Info.plist")" == local.nikema.clipboard-remix ]] || exit 1
codesign --verify --deep --strict "$SOURCE"
codesign --verify -R='anchor apple generic and certificate leaf[subject.OU] = "NFQXSAK9D4"' "$SOURCE"
mkdir -p "${DEST:h}"
ditto "$SOURCE" "$DEST"
codesign --verify --deep --strict "$DEST"
print -- "Installed: $DEST"
print -- "Launch at Login remains unchanged. Enable it yourself in the palette gear menu."
