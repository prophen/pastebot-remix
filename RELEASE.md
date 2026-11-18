# Preparing a release

This guide is for maintainers distributing Clipboard Remix directly, outside the Mac App Store. End-user instructions belong in [README.md](README.md); source builds are covered in [BUILDING.md](BUILDING.md).

The workflow is **test → sign → notarize → staple → verify → publish**. The scripts prepare local artifacts and submit to Apple; they do not publish a GitHub Release.

## Public-release prerequisites

Version 0.5.0 removes the runtime dependency on the build machine’s external drive: login registration supports /Applications and ~/Applications, and preview/drag exports use per-user Application Support. The optional installer supports standard locations without a fixed signing team.

For a prerelease:

- Pass the automated tests, signature, notarization, stapled-ticket, and Gatekeeper checks.
- Extract the final archive into a new directory, install it into an empty supported destination, and verify its runtime paths and launch.
- Disclose same-Mac coverage. A second Mac or fresh user account is valuable additional testing, but is not required to prepare a prerelease.
- Keep untested minimum-OS, hardware, login-session, and display scenarios in the release notes. Invite early testers before declaring broad compatibility.

A clean same-Mac installation does not reproduce another Mac, a new account’s permissions, or a real browser download. Label exactly which checks were performed.
## One-time signing and notarization setup

On the release Mac:

1. Use an Apple Developer account/team with access to Developer ID signing.
2. Create or install a **Developer ID Application** certificate and its private key in the login Keychain. A certificate without its private key cannot sign the app.
3. Confirm the identity and required tools:

   ```sh
   security find-identity -v -p codesigning
   xcrun --find notarytool
   xcrun --find stapler
   ```

4. Store notarization credentials in a named Keychain profile:

   ```sh
   xcrun notarytool store-credentials clipboard-remix-notary \
     --keychain "$HOME/Library/Keychains/login.keychain-db"
   ```

   Follow the interactive prompts for Apple Account, team ID, and an app-specific password. An App Store Connect API key is another supported authentication method. Keep credentials out of source files, release assets, and shell command arguments.

Do not create another certificate/profile if valid ones already exist. Allow legitimate macOS signing prompts yourself; do not bypass Keychain access protections.

See Apple’s [Developer ID certificate instructions](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/) and [notarization workflow](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution/).

The project has successfully used Command Line Tools for this workflow without full Xcode. See [BUILDING.md](BUILDING.md) for the verified compiler/SDK and the current pinned SDK path.

## Prepare the source and environment

Run on an Apple Silicon Mac, from the repository root.

1. Set `CFBundleShortVersionString` to the release version and increment `CFBundleVersion` in `scripts/Info.plist`. Use a new version/build for changed application code rather than silently replacing an existing artifact.
2. Update user-facing docs and record test results. Commit all intended source changes.
3. Choose an absolute build-output directory with enough space, and set the installed signing identity:

   ```sh
   export CLIPBOARD_BUILD_ROOT="/absolute/path/to/clipboard-remix-build"
   export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
   export NOTARY_PROFILE="clipboard-remix-notary"
   mkdir -p "$CLIPBOARD_BUILD_ROOT"
   ```

   Replace the example path and identity. On the existing maintainer machine, use `/Volumes/Expansion/pastebot-remix-build`; its internal disk is not the artifact destination.

4. Check that the checkout is clean, then test:

   ```sh
   git status --short
   ./scripts/build.sh test
   ```

   Commit intended changes before packaging. The release script rejects a dirty checkout and records the exact source commit.

## Sign the application

```sh
./scripts/release.sh prepare
```

This builds the app, creates a unique directory under `$CLIPBOARD_BUILD_ROOT/releases`, signs with hardened runtime and a secure timestamp, verifies the Developer ID signature, and creates `submission.zip`.

Save the printed directory, then capture the version and source commit from those artifacts:

```sh
release_dir="$CLIPBOARD_BUILD_ROOT/releases/release-XXXXXXXX"
release_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$release_dir/Clipboard Remix.app/Contents/Info.plist")
release_commit=$(cat "$release_dir/source-commit.txt")
```

Replace `release-XXXXXXXX` with the actual directory. Keep this directory throughout notarization. **Do not distribute submission.zip**; it contains the signed app before stapling.

## Submit to Apple and finish

```sh
./scripts/release.sh submit "$release_dir"
```

This uploads the submission and saves its receipt without waiting. Later, check and finish:

```sh
./scripts/release.sh finish "$release_dir"
```

- **In Progress:** the command stops without producing a distribution archive. Run `finish` again later; do not submit the same build again.
- **Invalid / Rejected:** inspect `notarization-log.json`, fix the cause, and prepare a new build.
- **Accepted:** the script staples the ticket, validates it, verifies the code signature, runs Gatekeeper assessment, and creates the public ZIP and checksum.

Final assets:

```text
Clipboard-Remix-<version>-arm64.zip
Clipboard-Remix-<version>-arm64.zip.sha256
```

`finish` refuses to overwrite an existing final ZIP. Once it succeeds, continue to verification rather than repeatedly running it.

Optional environment overrides are `NOTARY_PROFILE`, `NOTARY_KEYCHAIN` (defaults to the login Keychain), and `CLIPBOARD_BUILD_ROOT`. The app’s runtime paths remain account-relative; these settings only affect release preparation.

## Verify the exact distribution archive

Use the final ZIP, not the unarchived build directory:

```sh
(cd "$release_dir" && shasum -a 256 -c "Clipboard-Remix-$release_version-arm64.zip.sha256")
verify_dir=$(mktemp -d "$CLIPBOARD_BUILD_ROOT/verify-XXXXXXXX")
ditto -x -k "$release_dir/Clipboard-Remix-$release_version-arm64.zip" "$verify_dir"
codesign --verify --deep --strict "$verify_dir/Clipboard Remix.app"
xcrun stapler validate "$verify_dir/Clipboard Remix.app"
spctl --assess --type execute --verbose=2 "$verify_dir/Clipboard Remix.app"
```

Test that archive through a fresh installation on the available Mac using the [manual acceptance checklist](TESTING.md#manual-acceptance-checklist). If another Mac or a separate user account is available, extend testing there. Verify the installed executable’s `--diagnostics` output reports a supported login location and per-user data/export directories. State the exact tested environment and untested scenarios in release notes. Do not rebuild or modify the signed app after notarization; changed binaries need a new signing/notarization pass.

## Create a GitHub draft release

Do this only once the release prerequisites and artifact checks pass. A source tag alone is not an installable app release.

With GitHub CLI authenticated for the repository, tag the **recorded build commit**, push that tag, and create a draft with the two final assets:

```sh
git tag -a "v$release_version" "$release_commit" -m "Clipboard Remix $release_version"
git push origin "v$release_version"
gh release create "v$release_version" \
  "$release_dir/Clipboard-Remix-$release_version-arm64.zip" \
  "$release_dir/Clipboard-Remix-$release_version-arm64.zip.sha256" \
  --repo prophen/pastebot-remix \
  --verify-tag --draft \
  --title "Clipboard Remix $release_version" \
  --notes-file release-notes.md
```

Write `release-notes.md` first. Include requirements, installation, changes, known limitations, and notarization/test status. Use your own repository for a fork. If the version/tag already exists, inspect it; do not overwrite a published release with different bytes under the same version.

Review the draft’s version, source commit, assets, and notes. Mark a limited preview as a prerelease. Publishing is a separate explicit step in the GitHub UI or CLI; the command above leaves it a draft. GitHub’s [release documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository?tool=cli) describes both workflows.

Upload only the final application ZIP and checksum as application assets. Keep credentials, private keys, submission receipts, and working files out of the release.

## Current project status

Version 0.5.0 build 10 is the first portable prerelease candidate and has passed signing, Apple notarization, final-archive verification, and installation/launch on the development Mac. The existing maintainer machine already has a Developer ID identity and the `clipboard-remix-notary` profile configured; other maintainers need their own credentials. Prior versions’ notarization tickets do not cover this candidate.

See [TESTING.md](TESTING.md) and the candidate’s release-directory receipts for the verification outcome. Version 0.5.0 was published as a prerelease after asset review and manual acceptance. For future releases, keep the GitHub draft unpublished until its assets and notes are reviewed and publication is approved.
