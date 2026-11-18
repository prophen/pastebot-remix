# Testing and bug reports

For usage, see [README.md](README.md). For toolchain setup, see [BUILDING.md](BUILDING.md).

## Automated verification

Run from the repository root with a configured build directory:

```sh
./scripts/build.sh test
```

The script runs **14 core check groups** plus native palette/model checks. It uses isolated named pasteboards, disposable history databases, and test preferences. It does not paste into real apps or clear real history. Native test palettes may briefly appear.

Coverage includes:

- Text/image persistence, Unicode and multiline text, search and type filters.
- PNG/TIFF handling, thumbnails, preview preparation, invalid images, file cleanup and recovery.
- Retention limits, pinned favorites, migrations, and full-capacity behavior.
- Own-write suppression, pause/resume boundaries, and sensitive clipboard markers.
- Paste-delivery focus checks, cancellation, clipboard changes, and timeout.
- Window geometry, display recovery calculations, actual hosting-view sizing, close/reopen, and saved-preference restoration.
- Timed pause expiry, simulated sleep gaps, cancellation, and resume-time clipboard suppression.
- Copy feedback, rapid replacement, expiry, error preservation, and keyboard dismissal.
- Exact text and normalized-image deduplication, pins, hash collisions, transparency, and recopy.
- Native PNG file-URL drag representations, snapshot lifetime, repeated exports, cleanup, and volume checks.
- Portable per-user storage, standard Applications login eligibility, and first-run/repeated exports with an alternate test home.

Test fixtures use the explicit build-volume path supplied by the script because Foundation may ignore TMPDIR on macOS.

## Manual acceptance checklist

Use a disposable document and benign clips. Do not submit forms or send messages just to test insertion.

1. Copy text and a screenshot; find them through search and filters.
2. Single-click to paste into the intended field; confirm the palette remains open. Double-click to copy only. Check arrows, Return, Command-1…9, Escape, and switching destination fields.
3. Move and resize the palette; close/reopen and quit/relaunch. Test a disconnected display and full-screen Spaces when available.
4. Pin text and an image; confirm matching favorites appear first and persist across restart. Unpin and verify normal ordering.
5. Copy the same text/image again; confirm the existing item refreshes. Confirm different whitespace is not collapsed.
6. Check Pause for 15 Minutes, its displayed deadline, manual Resume, indefinite pause, and a real sleep/wake boundary. Relaunch should start capture unpaused.
7. Check brief copy/paste feedback, including keyboard dismissal and rapid repeated actions. Errors must remain visible until dismissed.
8. Drag an image preview into a document and browser upload target. Cancel another drag; verify history remains. Repeat the export.
9. From a supported installed location, enable Launch at Login, approve if needed, log out/in, verify quiet capture, then disable and verify it no longer launches. Do not log out until your other work is saved.

## Recorded results and limits

For v0.4.1 build 9:

- All automated checks passed; the release build and Developer ID signature verification passed.
- Manual checks confirmed native image dragging into **TextEdit** and **Comet + ChatGPT**, including cancellation.
- Earlier feature checks confirmed favorites, login-registration controls, and the corrected palette close/reopen size behavior. Earlier builds also received field-level text/image paste and follow-focus confirmation.
- These observations do not establish every destination app, every macOS version, or every display arrangement.
- Real timed sleep/wake, physical display disconnection, login-session launch, minimum-OS compatibility, and clean installation on another Mac remain release-test gaps.
- Version 0.4.1 was signed locally but has not completed this project’s notarization/public-distribution verification.

The [verification history](docs/VERIFICATION-HISTORY.md) preserves per-build findings and fixes. Historical “pending” statements describe that build and may be superseded later.

## Prerelease verification: v0.5.0 build 10

- All 14 core groups and native palette/model checks pass. New tests use an alternate home with spaces and confirm login eligibility only in standard Applications locations, plus first-run/repeated exports in per-user Application Support.
- Installation helper checks verify Developer ID signing and an optional publisher team, accept standard destinations, and reject invalid destinations, mismatched signatures, and existing apps without replacement.
- Build artifacts and isolated fixtures remain on Expansion; distributed runtime storage does not depend on that volume.
- Apple accepted notarization. The final ZIP checksum passed; a fresh extraction passed strict signature verification, stapled-ticket validation, and Gatekeeper assessment (Notarized Developer ID).
- Installed the extracted archive into an empty ~/Applications destination and confirmed build 10 running there on macOS 26.6.2, Apple Silicon. Read-only diagnostics confirmed supported login location and account-relative history/export paths. Real history was not cleared.
- Existing Launch at Login registration was left unchanged. Startup after relocation subsequently passed after manual re-registration (see follow-up below). Browser-download quarantine behavior, another Mac, a separate macOS user account, and minimum-OS coverage remain unverified. The user subsequently confirmed all steps in the build 10 manual smoke pass: existing history and pins, new text/image capture, palette sizing through close/reopen and quit/relaunch, single-click paste, double-click copy, Return copy-and-dismiss, image dragging into TextEdit and Comet + ChatGPT, drag cancellation, and Launch at Login controls. Automatic startup after logout/login was separately confirmed after re-registration. This short pass does not establish real sleep/wake, monitor disconnection, or every keyboard shortcut.

## Report a bug

Open an [issue](https://github.com/prophen/pastebot-remix/issues) with:

- App version/build, macOS version, and Apple Silicon model.
- Steps to reproduce, expected behavior, and actual behavior.
- For paste or drag failures: destination app/browser and target, whether copy-and-paste works, and any status message.
- For window failures: display arrangement and whether the change happened on close/reopen, relaunch, or display disconnection.

Use a benign example. Do not attach your clipboard database, private clipboard contents, signing credentials, or notarization secrets.

### Logout/login follow-up for build 10

The user reported that the app did not start after logout/login. The installed bundle remained in ~/Applications (not /Applications). Follow-up diagnostics reported SMAppService status 3 (notFound), and a filtered background-task registry inspection found no Clipboard Remix entry. The cause of the missing registration is not established. The app was reopened for manual re-registration. The user enabled Launch at Login from the installed copy, confirmed On, then confirmed the app started automatically after another logout/login. Login-session startup therefore passed after explicit re-registration on this Mac. Automatic registration migration when moving an older copy is not established.

### Comet click-to-paste follow-up: v0.5.1 build 11

After the build 10 smoke-pass report, the user supplied a Comet single-click paste failure showing “couldn’t confirm focus.” Build 11 requests Comet’s Chromium accessibility tree using AXEnhancedUserInterface (once per running browser after a successful request), reads the application role to activate native accessibility, and allows four seconds for Comet focus readiness because Chromium can debounce accessibility activation for two seconds. Electron retains AXManualAccessibility. Destination PID, stable field identity, clipboard-change and cancellation checks remain enforced.

Automated coverage includes delayed focus readiness beyond the old one-second window. Actual Comet field-level text/image paste acceptance is pending manual retest; no automated paste into real chats is performed. The published 0.5.0 artifact is unchanged.
