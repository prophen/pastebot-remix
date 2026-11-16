# Clipboard history MVP

## Outcome

A native Mac utility that remembers copied text and screenshots, survives restarts, and lets Nikema find and copy an earlier item back for normal Command-V pasting.

Design B from `design-prework/clipboard-history-sketches.html` is selected: one two-pane palette, history on the left and a large preview on the right. No application implementation exists yet.

## Scope

- Capture plain text and still images placed on the clipboard while the app runs.
- Store history locally across restarts.
- Open the palette from a menu-bar icon and a configurable global shortcut (proposed default Option-Command-V; handle conflicts).
- Show newest first, grouped by day, with text snippets or image thumbnails.
- Search text contents; filter All, Text, or Images. OCR and automatic descriptive image names are excluded.
- Preview wrapped text or the full image fitted without cropping; show time and image dimensions.
- Arrow keys select; Return or Command-1 through Command-9 copies the corresponding visible result and dismisses the panel; Escape dismisses without changing the clipboard.
- Return focus to the previous app so the user can paste with Command-V.
- Delete an entry, clear history with confirmation, pause/resume capture, and quit.
- Bound history by both item count and disk usage. Proposed initial defaults: 500 items and 500 MB of image files; remove oldest entries first. Oversized items must not silently defeat the cap.

## Stack and boundaries

Swift and SwiftUI for presentation; AppKit for clipboard, menu-bar integration, and panel behavior; SQLite for metadata and text; files in Application Support for images and thumbnails. Select minimum macOS target after checking the development Mac and toolchain. Use a working product name until branding is decided.

Separate ClipboardMonitor, HistoryStore, ImageStore, and PaletteController responsibilities. Keep file work and image processing off the UI path. UI displays thumbnails; load full images only for the selected preview.

Store an ID, kind, capture time, text or relative image path, thumbnail path, dimensions, byte size, and optional content fingerprint. Do not promise source-app attribution, original image filenames, or paste counts. Use image labels based on time and dimensions.

## Build sequence and exit criteria

### 1. Prove capture and restore

Create the smallest launchable Mac app. Capture one text item and one clipboard screenshot. Select each and restore it to the clipboard. Verify normal pasting in the actual text and image destinations Nikema uses. Prove panel focus/dismissal and shortcut behavior early.

Exit: copy text, copy a screenshot, retrieve both, and paste them successfully. Do this before visual polish or full history storage.

### 2. Persist a bounded history

Add SQLite records and image files, thumbnail generation, restart loading, and retention. Prevent the app's own clipboard writes from creating duplicate entries. Avoid repeated captures when the clipboard has not changed; preserve meaningful new copy actions. Treat multiple representations of one clipboard image as one entry.

Write files atomically before committing their records; recover from missing files and remove abandoned files. Capture failures must not crash or stall monitoring. Start history from launch onward rather than implying recovery of older clipboard contents.

Exit: mixed history survives relaunch; deletion/eviction cleans up files; a missing image is handled gracefully; repeated app copy-back does not grow history.

### 3. Build design B

Implement search, type filters, grouped list, selection, text/image previews, and empty/no-results states. Keep selection stable when new copies arrive. Search and filters operate together. Empty or vanished results disable copy actions safely.

Exit: a mixed history can be browsed by mouse and keyboard, with quick selection from the currently visible results and no full-resolution image decoding during ordinary list scrolling.

### 4. Make it dependable for daily use

Finish menu-bar controls, shortcut conflict handling, focus restoration, pause capture, deletion, clearing, and bounded storage settings. Respect recognized sensitive/transient clipboard markers where available, without claiming universal secret detection. Make local storage and capture state understandable.

Exit: closing the palette keeps capture running; quitting stops it; pause actually stops saving; reopening and dismissing the panel works repeatedly.

### 5. Package and demo

Produce a launchable .app and concise usage notes. Verify launch outside Xcode and retention across a full app restart. If public distribution is required, plan signing/notarization separately from the local demo rather than assuming a development build will launch frictionlessly on other Macs.

Demo: copy a text snippet and two screenshots, copy something else, retrieve the earlier screenshot using the large preview, paste it, search for the text, then relaunch to show persistence.

## Verification

Use focused automated checks for search/filter behavior, retention rules, file-record consistency, and suppression of self-generated clipboard updates. Manually test clipboard round trips and panel focus in real destination apps; unit tests alone cannot establish paste compatibility.

Include large screenshots, transparent images, long/multiline text, non-ASCII text, rapid copies, restart, missing files, no matches, and deleting the selected item. Record any capture or format limitations honestly.

## Time allocation

Use the first build session for milestone 1, then persistence and the palette. Reserve the final portion of the hackathon for real-app testing, packaging, and demo preparation. If time tightens, simplify grouping, metadata, animations, and shortcut customization before cutting screenshot support or persistence.

## Deferred

OCR, cloud sync, AI transformations, rich-text preservation, arbitrary files, screenshot-folder monitoring, image editing, pins/collections, automatic pasting, and elaborate animation. Login launch can follow a reliable MVP.
