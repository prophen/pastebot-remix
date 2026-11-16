#!/bin/zsh
# Release artifacts stay on Expansion. Credentials are read from the login Keychain.
set -euo pipefail
cd "${0:A:h:h}"
BUILD_ROOT="${CLIPBOARD_BUILD_ROOT:-/Volumes/Expansion/pastebot-remix-build}"
PROFILE="${NOTARY_PROFILE:-clipboard-remix-notary}"
NOTARY_KEYCHAIN="${NOTARY_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
fail() { print -u2 -- "$*"; exit 1; }
[[ -d "$BUILD_ROOT" ]] || fail "Build directory is unavailable: $BUILD_ROOT"
case "${1:-}" in
  prepare)
    [[ "${SIGNING_IDENTITY:-}" == 'Developer ID Application: '* ]] || fail 'Set SIGNING_IDENTITY to the full Developer ID Application identity from security find-identity -v -p codesigning.'
    security find-identity -v -p codesigning | /usr/bin/grep -F -- "\"$SIGNING_IDENTITY\"" >/dev/null || fail 'The requested signing identity is not installed with its private key.'
    ./scripts/build.sh
    mkdir -p "$BUILD_ROOT/releases"
    RELEASE_DIR="$(mktemp -d "$BUILD_ROOT/releases/release-XXXXXXXX")"
    APP="$RELEASE_DIR/Clipboard Remix.app"
    ditto "$BUILD_ROOT/Clipboard Remix.app" "$APP"
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
    codesign --verify --deep --strict --verbose=2 "$APP"
    codesign --display --verbose=4 "$APP" 2> "$RELEASE_DIR/signature.txt"
    /usr/bin/grep -F 'Authority=Developer ID Application:' "$RELEASE_DIR/signature.txt" >/dev/null || fail 'Developer ID signature missing.'
    /usr/bin/grep -F '(runtime)' "$RELEASE_DIR/signature.txt" >/dev/null || fail 'Hardened runtime missing.'
    ditto -c -k --keepParent "$APP" "$RELEASE_DIR/submission.zip"
    git rev-parse HEAD > "$RELEASE_DIR/source-commit.txt"
    git diff --stat > "$RELEASE_DIR/source-changes.txt"
    print -- "Prepared signed submission (not yet notarized): $RELEASE_DIR"
    ;;
  submit)
    RELEASE_DIR="${2:?Supply the release directory printed by prepare}"
    [[ -f "$RELEASE_DIR/submission.zip" ]] || fail 'No prepared submission.zip.'
    [[ ! -e "$RELEASE_DIR/submission.json" ]] || fail 'A submission already exists; use finish to check it instead of uploading again.'
    xcrun notarytool submit "$RELEASE_DIR/submission.zip" --keychain-profile "$PROFILE" --keychain "$NOTARY_KEYCHAIN" --no-wait --output-format json > "$RELEASE_DIR/submission.pending.json"
    mv "$RELEASE_DIR/submission.pending.json" "$RELEASE_DIR/submission.json"
    print -- "Submitted. Run finish with this directory to check acceptance and package: $RELEASE_DIR"
    ;;
  finish)
    RELEASE_DIR="${2:?Supply the release directory printed by prepare}"
    [[ -f "$RELEASE_DIR/submission.json" ]] || fail 'No submission receipt.'
    SUBMISSION_ID="$(/usr/bin/plutil -extract id raw -o - "$RELEASE_DIR/submission.json")"
    xcrun notarytool info "$SUBMISSION_ID" --keychain-profile "$PROFILE" --keychain "$NOTARY_KEYCHAIN" --output-format json > "$RELEASE_DIR/notarization.json"
    RESULT="$(/usr/bin/plutil -extract status raw -o - "$RELEASE_DIR/notarization.json")"
    if [[ "$RESULT" != Accepted ]]; then
      if [[ "$RESULT" == Invalid || "$RESULT" == Rejected ]]; then
        xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$PROFILE" --keychain "$NOTARY_KEYCHAIN" "$RELEASE_DIR/notarization-log.json"
      fi
      fail "Apple status: $RESULT. No distribution ZIP created."
    fi
    APP="$RELEASE_DIR/Clipboard Remix.app"
    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"
    codesign --verify --deep --strict "$APP"
    spctl --assess --type execute --verbose=2 "$APP"
    VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
    ZIP="$RELEASE_DIR/Clipboard-Remix-$VERSION-arm64.zip"
    [[ ! -e "$ZIP" ]] || fail "Distribution ZIP already exists: $ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    (cd "$RELEASE_DIR" && shasum -a 256 "${ZIP:t}" > "${ZIP:t}.sha256")
    print -- "Ready to share: $ZIP"
    ;;
  *)
    print -u2 'Usage: SIGNING_IDENTITY="Developer ID Application: …" ./scripts/release.sh prepare'
    print -u2 '       ./scripts/release.sh submit <release-directory>'
    print -u2 '       ./scripts/release.sh finish <release-directory>'
    exit 2
    ;;
esac
