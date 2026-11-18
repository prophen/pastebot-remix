# Clipboard Remix

A native Mac clipboard manager for copied text and screenshots. Find an earlier clip, preview it, and copy or paste it into another app. History stays on your Mac.

## Requirements and availability

- Apple Silicon Mac. Current builds target macOS 14 or later; the minimum supported OS still needs release testing.
- Accessibility permission is required for click-to-paste. Copying a clip and pasting it yourself does not require that permission.
- Current source version: **0.5.0**, prepared as an Apple Silicon prerelease. See the release’s notes for signing/notarization status and the scope of verification.

Check [GitHub Releases](https://github.com/prophen/pastebot-remix/releases) for published downloads and their release-specific requirements. Download an application ZIP from **Assets**, not GitHub’s automatically generated source-code archive. If no suitable application asset is available, see [Building from source](BUILDING.md).

**Prerelease coverage:** verification is limited to one Mac. Other hardware, macOS versions, and a fresh user account have not been tested. This is disclosed rather than treated as a requirement to own a second Mac.

## Install and start

For a published, notarized application build:

1. Download and unzip the application ZIP from the release’s Assets.
2. Move **Clipboard Remix.app** to **Applications** (or your home folder’s **Applications** directory), then open it.
3. Look for the clipboard icon in the menu bar. Launch is quiet; click the icon or press **Option-Command-V** to open the palette.
4. Copy some text or an image in another app. It appears in history while capture is running.

The app does not import clipboard content that was already present when it launched. Closing the palette leaves capture running; choose **Quit Clipboard Remix** from the gear or menu-bar menu to stop it.

If macOS reports a damaged or unverified download, check the release’s signing/notarization status and download it again from the release page. Report the exact message rather than disabling Gatekeeper.

## Find and reuse a clip

Type in the search field to search text, and use **All / Text / Images** to filter results. Images have capture-time and dimension labels; image contents are not searchable.

| Action | Result |
|---|---|
| Single-click a history row | Paste into the last focused external app; keep the palette open |
| Double-click a row | Copy only; keep the palette open |
| Up / Down | Select and preview without pasting |
| Return or **Copy ↩** | Copy the selected result and close the palette |
| Command-1…9 | Copy one of the first nine filtered results and close the palette |
| Escape | Close without replacing the clipboard |
| Command-Delete | Delete the selected history item |
| Option-Command-V | Open or close the palette |

Single-click paste waits briefly to distinguish a double-click. Right-click a row for **Preview**, **Copy Only**, and **Pin Favorite / Unpin**.

The palette remembers its size and position across closes and restarts, and brings an off-screen frame back onto an available display. Its normal minimum size is 740 × 490.

### Click-to-paste permission and destination

Enable Clipboard Remix in **System Settings → Privacy & Security → Accessibility**, then focus a destination field and reopen the palette.

The footer shows **Paste → [app]**. While the palette remains open, focus another app or field to change the destination. Once a paste starts, that destination is locked for the operation. If the app cannot verify focus, it reports an error; use Copy and Command-V instead.

Successful actions briefly show **Copied** or **Paste sent to [app]**. The menu bar also shows confirmation when a keyboard copy closes the palette. Feedback disappears after two seconds; errors remain until dismissed. “Paste sent” confirms event delivery, not that the receiving app inserted the content. Clipboard Remix never presses Return to submit a form.

### Favorites and repeated copies

Pin text or images from the row context menu. Matching favorites appear first and still respect search and type filters.

Copying identical text or equivalent normalized image content refreshes the existing entry’s time instead of creating another. Its pin and files are preserved. Refreshed clips move to the top of their pinned or unpinned section. Text is not trimmed, so whitespace differences remain distinct. Existing duplicate rows from older versions are not automatically deleted.

### Drag images

Drag an image’s **large preview** into a compatible document or file-upload target after it loads. Dragging or cancelling a drag does not paste or delete the history item.

Native PNG file dragging was manually verified with TextEdit and Comet + ChatGPT in build 9. Other receivers may handle file drops differently. Preview snapshots use your account’s Application Support folder; no developer drive is required.

### Pause capture

The gear and menu-bar menus provide:

- **Pause for 15 Minutes:** shows the resume time and resumes when the deadline passes, including after sleep.
- **Pause Indefinitely:** stays paused for the current app session.
- **Resume Capture:** resumes immediately and cancels a timed pause.

Pauses do not survive quitting: every launch starts capture unpaused. Copies made while paused are not imported when capture resumes.

### Launch at Login

Launch at Login is opt-in. The gear menu shows the system’s registration status and provides enable, disable, refresh, and Login Items settings controls. **Approval required** means macOS needs your approval in System Settings.

Install in **/Applications** or **~/Applications** before enabling this feature. Copies running from Downloads, a temporary release folder, or a mounted archive cannot register. Disable Launch at Login before moving an already registered app, then open the new installed copy and enable it again if desired. Registration never happens automatically.

## Storage, privacy, and deletion

History is stored in your account at:

`~/Library/Application Support/ClipboardRemix/`

It contains `history.sqlite` and an `Images/` folder with PNG images and thumbnails. Clipboard Remix has no history sync or automatic uploads. Dropping an image into a website hands it to that site; the site controls what happens next.

History is **unencrypted on disk**. Pause before copying content you do not want saved. Recognized concealed, transient, generated, and file-URL clipboard markers are skipped, but this is not universal sensitive-content detection.

Limits are currently fixed:

- 500 history entries.
- 500 MB of stored image files, including thumbnails.
- 2 MB of text per entry.
- Images larger than 80 megapixels or the image storage limit are skipped with a status message.

Oldest unpinned entries are removed first. Favorites count toward the limits but are protected from automatic eviction. If favorites leave no capacity, new distinct captures are skipped; an existing duplicate can still be refreshed. Unpinning makes an item eligible for eviction immediately.

**Delete Selected** can remove a favorite. **Clear History** removes all saved entries, including favorites and their history image files, after confirmation. Neither action clears the current system clipboard.

Image previews prepare independent PNG snapshots in `~/Library/Application Support/ClipboardRemix/DragExports/` for dragging. These stay available while a preview or drag uses them, then receive a seven-day grace period. Expired inactive snapshots are cleaned on the next export. These copies can therefore outlive deleting or clearing history.

## Known limitations

- Capture polls every 0.4 seconds; very rapid copies may be missed. A full processing queue reports skipped captures.
- Plain text and still PNG/TIFF images are supported. Rich text becomes plain text. Files, OCR, editing, cloud sync, and collections are not supported.
- Shortcut selection is limited to Option-Command-V and Shift-Option-Command-V. Right-click the menu-bar icon to switch; registration failures are reported.
- Actual sleep/wake, physical multi-display disconnection, full-screen Spaces, minimum-OS compatibility, and installation on another Mac need broader manual coverage. See [Testing](TESTING.md).

## Development and support

- [Build from source](BUILDING.md)
- [Run tests and report a bug](TESTING.md)
- [Prepare a signed, notarized release](RELEASE.md)
- [Original design plan](MVP-PLAN.md) — historical, not current usage instructions
- [Issue tracker](https://github.com/prophen/pastebot-remix/issues)
