#!/bin/zsh
# Install a verified app into an empty standard Applications location.
# This helper neither replaces existing apps nor changes login registration.
set -euo pipefail
fail() { print -u2 -- "$*"; exit 1; }
usage() {
  print -u2 'Usage: ./scripts/install.sh [--check] "/path/to/Clipboard Remix.app" ["/Applications/Clipboard Remix.app"]'
  print -u2 'Default destination: ~/Applications/Clipboard Remix.app'
  print -u2 'Optional EXPECTED_TEAM_ID requires a specific Developer ID signing team.'
  exit 2
}
CHECK_ONLY=false
if [[ "${1:-}" == --check ]]; then
  CHECK_ONLY=true
  shift
fi
(( $# >= 1 && $# <= 2 )) || usage
SOURCE="${1:a}"
DEST="${2:-$HOME/Applications/Clipboard Remix.app}"
DEST="${DEST:a}"
[[ "$DEST" == "$HOME/Applications/Clipboard Remix.app" || "$DEST" == '/Applications/Clipboard Remix.app' ]] ||
  fail 'Choose ~/Applications/Clipboard Remix.app or /Applications/Clipboard Remix.app.'
[[ ! -e "$DEST" && ! -L "$DEST" ]] ||
  fail "Destination already exists; leaving it untouched: $DEST"
[[ ! -L "${DEST:h}" ]] ||
  fail "Applications directory is a symbolic link; install manually after checking its destination: ${DEST:h}"
[[ -d "$SOURCE" && -f "$SOURCE/Contents/Info.plist" ]] ||
  fail "Source is not an application bundle: $SOURCE"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE/Contents/Info.plist")" == local.nikema.clipboard-remix ]] ||
  fail 'Source has an unexpected bundle identifier.'

# Require Apple's Developer ID Application certificate chain, not ad-hoc,
# self-signed, or Mac App Store signing. Forks may use their own Developer ID team.
REQUIREMENT='identifier "local.nikema.clipboard-remix" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists'
if [[ -n "${EXPECTED_TEAM_ID:-}" ]]; then
  [[ "$EXPECTED_TEAM_ID" =~ '^[A-Z0-9]{10}$' ]] ||
    fail 'EXPECTED_TEAM_ID must be a ten-character Apple team identifier.'
  REQUIREMENT="$REQUIREMENT and certificate leaf[subject.OU] = \"$EXPECTED_TEAM_ID\""
fi
codesign --verify --deep --strict -R="$REQUIREMENT" "$SOURCE"
if $CHECK_ONLY; then
  print -- "Verified source: $SOURCE"
  print -- "Available supported destination: $DEST"
  print -- 'Check only: no files installed and no login setting changed.'
  exit
fi

mkdir -p "${DEST:h}"
# Atomically reserve the destination. A concurrent install or newly created
# symlink makes this fail instead of merging into an unknown app.
mkdir "$DEST" || fail "Could not reserve an empty destination; nothing was overwritten: $DEST"
if ! ditto "$SOURCE" "$DEST" || ! codesign --verify --deep --strict -R="$REQUIREMENT" "$DEST"; then
  fail "Installation did not complete. An incomplete app remains at $DEST; inspect it before retrying."
fi
print -- "Installed: $DEST"
print -- 'Quit any older running copy before opening this app.'
print -- 'Launch at Login remains unchanged. Enable it yourself in the palette gear menu.'
