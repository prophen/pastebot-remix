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
- Login launch and the explicitly deferred product features are not implemented. Public download testing on another Mac is still pending.

The test document created in TextEdit and the two demonstration history entries are left available for inspection. The generated PNG fixture is under `/Volumes/Expansion/pastebot-remix-build/clipboard-test.png`.

## Developer ID release verification

- Developer ID Application signing succeeded with hardened runtime and a secure timestamp.
- Apple accepted notarization submission `9c41ab05-56bd-43ba-9155-dbb397ee254c` on November 16, 2026.
- The notarization ticket was stapled and validated.
- The final ZIP was extracted into a fresh directory; signature validation, ticket validation, and Gatekeeper assessment all passed (`source=Notarized Developer ID`).
- The notarized app launched successfully and loaded the existing history.
- The final archive is `Clipboard-Remix-0.1.0-arm64.zip`, for Apple Silicon. It has not been published as a GitHub Release.

## Version 0.2.0 — click to paste

- Eight automated check groups pass. The added checks cover waiting for stable destination focus, cancelling when a request or clipboard changes, target exit, and timeout without sending Paste.
- Verified the permission-denied path shows Accessibility setup instructions without queuing a paste. The user enabled the app in Privacy & Security → Accessibility.
- The user confirmed a text row pasted into the focused TextEdit document without pressing Command-V.
- Native automation was invoking the shortcut with T3 as the actual foreground app. These automated TextEdit attempts are not counted as successful destination tests. The destination is now named in the footer and remains fixed for the entire palette session; reopen notifications while visible cannot replace it.
- Arrow keys preview; row context menus offer Preview and Copy Only. Return, Command-1…9, and the Copy button remain copy-only.
- The user also confirmed that clicking an image row pasted the image into TextEdit. Text and PNG/TIFF use the same restore path.
- Apple accepted corrected build submission `86b4229b-afcf-4b3d-b933-047b545b108c`. The final `Clipboard-Remix-0.2.0-arm64.zip` was extracted and passed signature, stapled-ticket, and Gatekeeper verification. The earlier intermediate 0.2.0 archive was withdrawn during testing.

## Version 0.2.1 — change paste destination by focus

- The open palette follows activation of other apps and updates its destination footer. Activating Clipboard Remix itself does not replace the external destination.
- The destination's focused field is read at click time, so changing fields or windows within the same app is supported. Once a paste starts, its app/field snapshot stays fixed and the existing delivery guards still apply.
- All eight automated check groups pass. The user confirmed that leaving the palette open, focusing a different location, and clicking a history item pastes into the new location.
- Apple accepted notarization submission `54f6f1ba-75a4-40ec-a1aa-2b5314d1c3c7`; the 0.2.1 app is stapled and Gatekeeper-accepted.
