# MVP verification — November 16, 2026

## Build environment

- Apple Silicon Mac, macOS 26.6.2; Swift 6.4 Command Line Tools.
- SwiftUI + AppKit feasibility probe compiled and ran without Xcode.
- Release `.app` assembled by `scripts/build.sh`, ad-hoc signed, and launched through Launch Services.
- SDK pinned to the installed macOS 26.5 SDK. The default macOS 27 SDK exposed a SwiftUI macro whose implementation was unavailable in Command Line Tools.
- XCTest is absent from Command Line Tools. `./scripts/build.sh test` builds and runs the standalone `ClipboardChecks` executable instead.
- Build artifacts and task caches are on Expansion; source stays in this repository.

## Automated checks: passed

Seven check groups cover:

1. SQLite reload of mixed text/images, Unicode and multiline text (including embedded NUL), case-insensitive search, and combined kind filters.
2. Image dimensions and alpha representation, PNG/TIFF preparation, preview preparation, missing-file recovery, and orphan removal.
3. Count and image-byte retention, oldest-first eviction, and deletion/clear file cleanup.
4. Invalid and oversized images rejected without orphan files.
5. Change-count tracking: no repeated reads or self-write duplicates; later identical copy actions remain distinct.
6. Isolated named pasteboard text and PNG/TIFF round trips, preserving original PNG data and readable dimensions.
7. Pause/resume boundaries and recognized concealed/transient/generated/file markers.

## Live checks: observed

- Empty launch showed a focused search field and disabled Copy.
- Text copied in TextEdit appeared in history; Return restored it and normal Command-V pasted it into TextEdit.
- Mixed text and image history survived terminating and relaunching the final packaged app.
- Option-Command-V reopened the palette; Escape dismissed it; search received focus on reopen.
- No-match search disabled Copy, and the Images filter selected only images.
- A generated 640 × 360 transparent PNG fixture placed on the system clipboard appeared with a thumbnail and an uncropped large preview.
- Command-1 restored the image; Command-V pasted a visible image attachment into TextEdit.
- SQLite still contained exactly one text item and one image after these restores: copy-back did not create duplicate entries.
- Pause and Resume worked from the gear menu in the final build, with the capture status updating visibly. Palette keyboard shortcuts yield to open menus.
- A focus-change dismissal race found during live checks was removed. The palette stays visible until explicitly dismissed or copied from.

## Remaining manual checks and limitations

- Actual macOS screenshot-shortcut capture still needs a manual pass. The automated UI screenshot shortcut did not produce a screenshot; image verification used a PNG fixture instead.
- Test screenshot pastes in Nikema's everyday image destinations. Preview automation repeatedly timed out, so it is not claimed as verified.
- Test full-screen Spaces, multiple displays, other global shortcut conflicts, and sustained capture of large screenshots.
- Storage limits are fixed at 500 entries / 500 MB of image files, rather than exposed as settings. Shortcut choice is limited to two presets.
- Polling can miss copies less than 0.4 seconds apart; a bounded queue skips copies if processing falls behind and reports it in the palette.
- Captured text and images are local and unencrypted. Sensitive marker handling is best effort.
- Distribution signing/notarization, login launch, and the explicitly deferred features are not implemented.

The test document created in TextEdit and the two demonstration history entries are left available for inspection. The generated PNG fixture is under `/Volumes/Expansion/pastebot-remix-build/clipboard-test.png`.
