# Clipboard Remix

A local, native Mac clipboard history for plain text and screenshots. The MVP uses SwiftUI, AppKit, SQLite, and local PNG files. Requires macOS 14 or later; the local build targets Apple Silicon.

## Build and run without Xcode

```sh
./scripts/build.sh
open "/Volumes/Expansion/pastebot-remix-build/Clipboard Remix.app"
```

The script uses Command Line Tools and the installed macOS 26.5 SDK. Build products, temporary files, and task-specific compiler caches live under `/Volumes/Expansion/pastebot-remix-build`. Mount Expansion first. For a different build location, set `CLIPBOARD_BUILD_ROOT`. No package dependencies are downloaded.

The app is ad-hoc signed for local development. It is not notarized or ready for public distribution. Keep the external drive mounted while running this copy of the app.

## Use

- Capture starts when the app launches. It does not import whatever was on the clipboard before launch.
- Click the clipboard menu-bar icon or press **Option-Command-V** to open the palette.
- Type to search text; choose **All / Text / Images**. Images have time and dimension labels, with no OCR or filename search.
- Use **Up/Down** to select, **Return** to copy and dismiss, or **Command-1…9** to copy one of the first nine filtered results. Then paste normally with **Command-V** in your destination app.
- **Escape** closes the palette without replacing the clipboard.
- **Command-Delete** deletes the selected history item. The gear menu offers pause/resume, clear with confirmation, and quit.
- Right-click the menu-bar icon for controls and an alternate **Shift-Option-Command-V** shortcut. Failed shortcut registration is reported; the working shortcut is retained when switching fails.
- Closing the palette leaves capture running. Quit from the gear or menu-bar menu to stop capture.

## Local data and limits

History is stored in `~/Library/Application Support/ClipboardRemix/`: `history.sqlite` plus `Images/` containing PNG originals and thumbnails. Nothing is uploaded. History is unencrypted on disk and accessible to your Mac account. Pause capture before copying anything you do not want saved.

The MVP keeps up to **500 entries** and **500 MB of image files including thumbnails**, evicting oldest entries first. Text is limited to 2 MB per entry. Images over the storage limit or 80 megapixels are skipped with a visible status message. Limits are currently fixed. Clearing saved history does not clear the current system clipboard.

Recognized concealed, transient, and generated clipboard markers are skipped, as are file URL copies. This is not universal secret detection. PNG and TIFF clipboard images are supported; images are normalized to PNG. Rich text becomes plain text. Files, OCR, editing, sync, collections, and automatic paste are outside this MVP.

Polling occurs every 0.4 seconds; multiple rapid copies between polls can be missed. Copies while paused or while the app is quit are not recorded. Re-copying the same content is a new entry; restoring an item through this app is not.

## Verification

```sh
./scripts/build.sh test
```

The standalone test executable runs without XCTest or Xcode. Tests use temporary storage on the build volume and isolated named pasteboards. They cover mixed persistence, Unicode/multiline text, search/filter combinations, image dimensions/transparency, copy-back representations, self-write suppression, pause/markers, retention, missing-file recovery, and orphan cleanup.

See [TESTING.md](TESTING.md) for observed results and remaining manual checks.
