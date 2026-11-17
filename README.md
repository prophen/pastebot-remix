# Clipboard Remix

A local, native Mac clipboard history for plain text and screenshots. The MVP uses SwiftUI, AppKit, SQLite, and local PNG files. Requires macOS 14 or later; the local build targets Apple Silicon.

## Build and run without Xcode

```sh
./scripts/build.sh
open "/Volumes/Expansion/pastebot-remix-build/Clipboard Remix.app"
```

The script uses Command Line Tools and the installed macOS 26.5 SDK. Build products, temporary files, and task-specific compiler caches live under `/Volumes/Expansion/pastebot-remix-build`. Mount Expansion first. For a different build location, set `CLIPBOARD_BUILD_ROOT`. No package dependencies are downloaded.

The default build is ad-hoc signed for local development. For Developer ID signing, Apple notarization, and a shareable ZIP, see [RELEASE.md](RELEASE.md). Keep the external drive mounted while running this copy of the app.

## Use

- Launch is quiet: capture starts without opening the palette. It does not import whatever was on the clipboard before launch.
- Click the clipboard menu-bar icon or press **Option-Command-V** to open the palette.
- The palette remembers its size and position across closes and relaunches, and moves back onto an available display after a monitor disconnects.
- Right-click a text or image row to **Pin Favorite / Unpin**. Matching favorites appear first with a pin indicator; search and type filters still apply.
- Type to search text; choose **All / Text / Images**. Images have time and dimension labels, with no OCR or filename search.
- The footer names the paste destination (for example, **Paste → TextEdit**). While the palette stays open, focus another app to change the destination. You can also focus a different field or window within the same app; the next row click uses that field.
- **Click a history row** to paste it into the most recently focused field outside Clipboard Remix. On first use, enable Clipboard Remix in **System Settings → Privacy & Security → Accessibility**, then focus your destination and reopen the palette. No paste is queued while permission is missing.
- Single-click a row to paste and keep the palette open. Double-click a row to copy only and keep it open; single-click paste waits briefly to distinguish a double-click.
- Use **Up/Down** to preview without pasting, or right-click a row and choose **Preview**.
- For copy-only behavior, use **Return** to copy and dismiss, or **Command-1…9** to copy one of the first nine filtered results. Then paste normally with **Command-V** in your destination app.
- **Escape** closes the palette without replacing the clipboard.
- **Command-Delete** deletes the selected history item. The gear menu offers pause/resume, clear with confirmation, and quit.
- Right-click the menu-bar icon for controls and an alternate **Shift-Option-Command-V** shortcut. Failed shortcut registration is reported; the working shortcut is retained when switching fails.
- Closing the palette leaves capture running. Quit from the gear or menu-bar menu to stop capture.

## Local data and limits

History is stored in `~/Library/Application Support/ClipboardRemix/`: `history.sqlite` plus `Images/` containing PNG originals and thumbnails. Nothing is uploaded. History is unencrypted on disk and accessible to your Mac account. Pause capture before copying anything you do not want saved.

The MVP keeps up to **500 entries** and **500 MB of image files including thumbnails**, evicting oldest unpinned entries first. Favorites count toward both limits and are never automatically evicted. If favorites fill the item limit, new captures are skipped with a status message. An image that cannot fit alongside pinned images is also skipped; text can still be saved when only the image budget is full. Unpinning makes an item eligible for eviction immediately. Existing favorites survive even if a future limit is lowered below their total. Text is limited to 2 MB per entry. Images over the storage limit or 80 megapixels are skipped with a visible status message. Limits are currently fixed. Explicit deletion can remove a favorite. **Clear History removes all entries, including favorites and their files**, after confirmation; it does not clear the current system clipboard.

Recognized concealed, transient, and generated clipboard markers are skipped, as are file URL copies. This is not universal secret detection. PNG and TIFF clipboard images are supported; images are normalized to PNG. Rich text becomes plain text. Files, OCR, editing, sync, and collections are outside this MVP.

Polling occurs every 0.4 seconds; multiple rapid copies between polls can be missed. Copies while paused or while the app is quit are not recorded. Re-copying the same content is a new entry; restoring an item through this app is not.

## Launch at Login (optional)

Launch at Login is off by default. The gear menu shows the actual macOS ServiceManagement status, with enable/disable, refresh, and Login Items settings controls. Approval-required means macOS is awaiting approval (or consent was revoked); it is not shown as enabled. Errors include recovery instructions. See [Apple’s status documentation](https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum).

For this external-drive build, the supported stable location is:

`/Volumes/Expansion/pastebot-remix-build/Installed/Clipboard Remix.app`

Prepare a Developer ID signed build using [RELEASE.md](RELEASE.md), then install it:

```sh
./scripts/install.sh '/Volumes/Expansion/pastebot-remix-build/releases/release-XXXXXXXX/Clipboard Remix.app'
open '/Volumes/Expansion/pastebot-remix-build/Installed/Clipboard Remix.app'
```

Quit any older running copy before opening the installed app. Installation refuses to overwrite an existing destination and does not enable login launch. Use the palette gear menu to opt in; disabling unregisters the app. **Expansion must be mounted and accessible at login**. If it is unavailable, launch the app yourself after mounting it. All launches start capture quietly; use the menu bar or Option-Command-V to open the palette.

Before replacing or moving the installed app, disable Launch at Login and quit it. Keep the previous known app as a backup, install the new signed build into the now-empty stable location, launch it, and opt in again if desired. Do not register temporary release-directory copies. A read-only diagnostic is available via the installed executable’s `--login-status` argument.

## Verification

```sh
./scripts/build.sh test
```

The checks run without XCTest or Xcode. In addition to the core executable, a test-only build exercises the real palette with isolated preferences and temporary history; test windows briefly appear. Tests use temporary storage on the build volume and isolated named pasteboards. They cover mixed persistence, Unicode/multiline text, search/filter combinations, image dimensions/transparency, copy-back representations, self-write suppression, pause/markers, retention, missing-file recovery, orphan cleanup, favorite migration/order/capacity protection, and display geometry recovery.

See [TESTING.md](TESTING.md) for observed results and remaining manual checks.

Click-to-paste sends the normal Command-V action to the last focused app after restoring its focused field. The destination app is locked when you click. Its focused field is captured then if available, or after the app regains keyboard focus; the field must remain stable before Paste is sent. It supports text and images wherever that destination accepts normal pasting. If focus cannot be verified, use Copy and paste manually. The app does not press Return or submit the destination form.
