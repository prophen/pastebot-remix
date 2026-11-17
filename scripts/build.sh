#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
BUILD_ROOT="${CLIPBOARD_BUILD_ROOT:-/Volumes/Expansion/pastebot-remix-build}"
if [[ ! -d /Volumes/Expansion && -z "${CLIPBOARD_BUILD_ROOT:-}" ]]; then
  print -u2 'Mount Expansion, or set CLIPBOARD_BUILD_ROOT to a directory with enough space.'
  exit 1
fi
mkdir -p "$BUILD_ROOT/cache" "$BUILD_ROOT/tmp"
export CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_ROOT/cache"
export TMPDIR="$BUILD_ROOT/tmp"
args=(--sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk --scratch-path "$BUILD_ROOT/scratch" --cache-path "$BUILD_ROOT/swiftpm-cache" --config-path "$BUILD_ROOT/config" --security-path "$BUILD_ROOT/security")
if [[ "${1:-}" == test ]]; then
  swift build "${args[@]}" --product ClipboardChecks
  BIN_DIR="$(swift build "${args[@]}" --show-bin-path)"
  "$BIN_DIR/ClipboardChecks"
  exit
fi
swift build "${args[@]}" -c release --product ClipboardRemix
APP="$BUILD_ROOT/Clipboard Remix.app"
mkdir -p "$APP/Contents/MacOS"
BIN_DIR="$(swift build "${args[@]}" -c release --show-bin-path)"
cp "$BIN_DIR/ClipboardRemix" "$APP/Contents/MacOS/ClipboardRemix"
cp scripts/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
printf '\nApp: %s\n' "$APP"
