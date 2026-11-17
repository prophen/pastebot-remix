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
- Login launch and favorites were subsequently implemented in 0.3.0 below; other deferred product features remain backlog. Public download testing on another Mac is still pending.

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

## Version 0.2.2 — persistent palette and double-click copy

- Single-click pastes while leaving the palette visible; it releases keyboard focus to the destination. The palette is now a nonactivating panel so opening it preserves the destination app's activation.
- Exclusive double/single tap recognition prevents a double-click from also triggering paste. Double-click restores text or image to the clipboard and keeps the palette open. Return and Command-1…9 retain copy-and-dismiss behavior.
- All eight automated check groups pass and the release build succeeds. These checks cover clipboard round trips and delivery guards, not native mouse gestures or focus behavior. Repeated paste with the palette open, double-click copy without pasting, and search/shortcut behavior require manual verification on this build.
- Paste failures now distinguish clipboard changes, unavailable destination, and focus timeout. The user's reported failure is not yet reproduced.

### Build 5 — Electron focus and approved app icon

- The reported screenshot identified failure to read T3 Code's focused Accessibility element before activation. Electron destinations now receive the documented AXManualAccessibility opt-in. If a field is unavailable while the palette owns keyboard focus, delivery waits for the locked destination app to regain focus, then acquires a field and requires stable checks before sending. No paste is sent without a readable field.
- Installed the approved icon in Resources/AppIcon.icns; the build copies it into Contents/Resources before signing and Info.plist declares AppIcon.
- All eight automated check groups pass. The user confirmed single-click paste into T3 Code works in build 5. This is a manual field-level result, not an automated TextEdit claim.


## Version 0.3.0 build 6 — first feature batch

- All **10 automated check groups pass** using `./scripts/build.sh test`. The eight existing clipboard/paste groups remain green.
- Favorites checks construct an actual pre-pin SQLite schema, migrate it without losing text, persist text/image pins across reopening, verify pinned-first ordering with combined search/type filters, and protect original/thumbnail files through recovery and count/byte pressure. They verify full-capacity capture rejection, no orphan files after rejection, text capture with a full pinned image budget, unpin eviction, explicit pinned deletion, and clear including pins.
- Geometry checks cover unchanged restoration, negative-coordinate secondary monitors, disconnected-display fallback, retained size, repeated restore, first-use centering, oversized and corrupt geometry, tiny displays, and no-screen handling.
- Tests use temporary directories on Expansion and isolated pasteboards. They do not clear or modify real history.
- Window moves/resizes save to UserDefaults. Reopening/relaunching restores that frame; screen changes clamp it to an available visible frame.
- Login controls use the actual `SMAppService.mainApp.status`, not a saved preference. Registration is only attempted on explicit enable from the stable installed copy. Disable unregisters; pending approval and failures are visible, with a System Settings action. Startup has no automatic palette presentation.
- Installation is restricted to a signed app at the documented stable Expansion path; the installer refuses existing destinations. Expansion must be available at login.

### Remaining manual checks for build 6

- Move and resize the palette, close/reopen, then quit/relaunch; physically disconnect its display while open and while quit. Geometry policy is automated, but these AppKit/display integration cases still need a manual pass.
- Pin/unpin real text and images through the context menu; verify indicators, grouping, selection, and keyboard result numbering while searching/filtering.
- Opt in to Launch at Login, approve in System Settings if requested, log out/in with Expansion mounted, verify quiet capture, then disable and confirm it no longer launches. Registration/approval mutations were deliberately not exercised because login launch must remain opt-in.
- Recheck single-click paste, exclusive double-click copy, keyboard copy/dismiss, and follow-focus in real destination fields on build 6. Build 5’s user-confirmed T3 Code paste remains the latest field-level result.
- No public release was published; notarization of this build is not part of this implementation pass.


### Signed installation observed

- Developer ID signing with hardened runtime and timestamp passed, as did strict signature validation. Version 0.3.0 build 6 was installed at `/Volumes/Expansion/pastebot-remix-build/Installed/Clipboard Remix.app` and launched successfully; the older build was quit.
- The installed executable’s read-only login status check returned **3 / notFound** before and after launch. No registration was enabled or disabled. The UI reports this actual status as service not found / not enabled.
- Native Computer Use inspection was not approved for Clipboard Remix, so no native UI checks are claimed for this build. The manual checks listed above remain outstanding.
- Read-only inspection confirmed the real database gained the pin column and still had six entries (zero pinned); no real clips were used as test fixtures.
- Re-running the installer against the occupied stable destination correctly refused to overwrite it.
- Final signed source build: `/Volumes/Expansion/pastebot-remix-build/releases/release-9EBpH4Qe/Clipboard Remix.app`; the same app is installed and running at the stable path. Strict signature validation passed. Notarization was not submitted.

## Version 0.3.1 build 7 — palette reopen size regression

- User manual acceptance: favorites (#3) and the Launch at Login control (#2) work. Those issues are closed. No actual logout/login test is claimed.
- User reported that palette size did **not** survive closing/reopening in build 6. The original geometry-only tests missed a native layout integration bug.
- Reproduced in the actual PaletteController/PaletteView: after layout, the root NSHostingView replaced the intended 740 × 490 window minimum with 351 × 188. Users could therefore shrink below the minimum enforced on reopening.
- A root hosting view with sizingOptions disabled still reset the window minimum to zero in a second failing check. The fix uses a plain AppKit container around the flexible SwiftUI hosting view, so AppKit retains control of window bounds.
- New native integration checks use temporary history and an isolated preferences suite. No clipboard monitor is started and no paste is sent. They exercise initial layout, asynchronous history loading, minimum-size ownership, move/resize, hide/reopen, close-button reopening at the minimum, and a new controller restoring saved preferences.
- All 10 existing core groups plus the native integration check pass via `./scripts/build.sh test`. The new check failed before the fix and passes afterward.
- The integration test is compiled only with PALETTE_CHECKS; release builds do not expose the test runner. Test windows may briefly appear during `build.sh test`.
- Physical display disconnection, actual logout/login, and a full user field-level paste regression pass remain manual limitations. This fix does not change paste delivery or gesture handlers.
- Framework reference: [Apple NSHostingView sizingOptions](https://developer.apple.com/documentation/swiftui/nshostingview/sizingoptions).
- Release build and Developer ID signing/strict signature validation passed. Build 7 is installed and running from the stable Expansion path; the known build 6 source remains in its release directory for rollback.
- The system still reports Launch at Login enabled after updating the known installed bundle in place; the update did not change registration or real history.
- User confirmed on build 7 that resizing, closing, and reopening with Option-Command-V preserves the size. The reported close/reopen regression is resolved; #1 is accepted for closure.

## Version 0.4.0 build 8 — second feature batch

Implemented issues #4–#7 with three subagents, followed by root integration and verification.

### Automated checks passed

- All **13 core check groups** pass via `./scripts/build.sh test`, followed by the native palette/model checks. Existing clipboard, paste-delivery, favorites, and window-size checks remain green.
- Timed pause: 15-minute deadline, exact expiry, simulated wake beyond expiry, manual Resume cancellation, replacement with indefinite pause, session-only relaunch policy. Model tests use a named pasteboard and verify that the clipboard copied during a pause is suppressed on resume while subsequent copies are captured.
- Feedback: successful text/image restoration, confirmation before keyboard dismissal, failed-image restoration without success feedback, replacement races, automatic expiry, and persistent error preservation. Paste success is reported only after the existing guarded event-delivery call returns; wording is “Paste sent,” not a claim of destination insertion.
- Deduplication: exact UTF-8 including whitespace/NUL/Unicode distinctions; timestamp/order refresh; preserved IDs and pins; full pinned capacity; reopening; PNG/TIFF equivalence; semitransparent image equivalence and normalized PNG recopy; distinct pixels/dimensions; deliberately forced candidate-hash collisions; lazy fingerprint backfill; missing-file recovery; no orphan files.
- Dragging: NSItemProvider PNG data and file representations deliver matching bytes after the disposable source history item is deleted. Starting/cancelling an unrequested provider creates no files and does not mutate history. Retention checks protect active requests, retain finished snapshots during the grace period, remove only marked expired folders, preserve unrelated files, and reject missing/mismatched volumes.
- The first drag-retention test caught an active-folder URL comparison mismatch. Active requests now use standardized path keys; the regression passes.
- Native palette checks also exercise pause/feedback/error layout without changing the restored frame. Tests use temporary storage on Expansion and isolated preferences/pasteboards; no real chat paste or real-history deletion is automated.

### Defined behavior

- Pause for 15 Minutes shows a deadline and resumes by wall time, with a wake notification and a common-runloop timer. Resume cancels it; indefinite pause replaces it. Every relaunch starts capture unpaused.
- Success feedback lasts two seconds in the palette and menu bar. Menu-bar text covers keyboard copy-and-dismiss without opening a window or stealing focus. A new error cancels old success feedback; success expiry never clears errors.
- New copies reuse an exact matching record, preserving favorites and files. Pinned items remain first; refreshed unpinned items head the unpinned section. Old duplicate rows are retained rather than deleted during migration.
- Image equality is dimensions plus native-orientation 8-bit sRGB premultiplied RGBA pixels, with SHA-256 candidate selection followed by full pixel equality. Text is never trimmed or Unicode-normalized for deduplication.
- Drag only from the large image preview. Providers own immutable PNG snapshots, never history-file URLs. Requested file snapshots live on Expansion in DragExports, with private permissions. macOS copies file representations for the receiver. Marked inactive producer snapshots expire after seven days and are cleaned on the next export; they can outlive clearing history.

### Remaining manual checks

- Exercise the timed-pause and Resume controls in both menus; verify the displayed deadline and a real sleep/wake boundary. Automated tests advance the clock rather than waiting 15 minutes.
- Observe brief text/image copy and paste feedback, including keyboard dismissal and rapid clicks, in actual destination fields. Recheck exclusive double-click copy and follow-focus; no automated paste into T3 Code was attempted.
- **Issue #6: drag a preview into a document app and a browser upload target**, and cancel a drag to verify history remains. Provider-level tests cannot establish each receiving app’s UI compatibility. This receiver acceptance check remains outstanding.
- No public release or notarization submission is part of this pass.

### Signed installation

- Release build and Developer ID signing with hardened runtime/timestamp passed; strict installed signature verification passed.
- Final signed build: `/Volumes/Expansion/pastebot-remix-build/releases/release-whV7978b/Clipboard Remix.app`. Version 0.4.0 build 8 is installed and running at the stable Expansion path.
- Read-only migration inspection found the new fingerprint column. Real history retained seven entries and one pin across the update. No historical duplicates were deleted.
- Launch at Login remains enabled (system status 1); the update did not change that setting.
