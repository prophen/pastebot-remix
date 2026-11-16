# Developer ID release

Use an Apple Developer ID Application certificate (with its private key in the login Keychain) and notarization to share the app outside the Mac App Store. Full Xcode is not required for this project's build/sign/notarize steps.

## One-time setup

1. Create a certificate signing request (CSR) and its private key on this Mac.
2. In [Apple Developer Certificates](https://developer.apple.com/account/resources/certificates/list), create a **Developer ID Application** certificate using that CSR. Download and import the issued certificate into the same Keychain as the private key. Do not revoke existing certificates to make room without checking what uses them.
3. Confirm `security find-identity -v -p codesigning` lists the identity.
4. Store notarization credentials in the Keychain:

   ```sh
   xcrun notarytool store-credentials clipboard-remix-notary --keychain "$HOME/Library/Keychains/login.keychain-db"
   ```

   This prompts for your Apple Account, team ID, and an app-specific password. Keep secrets out of Git and command history. An App Store Connect API key is another supported authentication method. Never use your ordinary Apple Account password as an app-specific password.

Apple's instructions: [Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/) and [notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Produce a release

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./scripts/release.sh prepare
```

The script builds locally, copies the app into a new directory under `/Volumes/Expansion/pastebot-remix-build/releases`, signs with hardened runtime and a secure timestamp, verifies the signature, and creates `submission.zip`. This intermediate ZIP is not the public download.

Pass the printed release directory into the next commands:

```sh
./scripts/release.sh submit '/Volumes/Expansion/pastebot-remix-build/releases/release-XXXXXXXX'
./scripts/release.sh finish '/Volumes/Expansion/pastebot-remix-build/releases/release-XXXXXXXX'
```

Submission returns without waiting. If `finish` reports `In Progress`, Apple is still processing; run it again later. A rejection produces a log for investigation and no distribution ZIP. Once accepted, the script staples and validates the ticket, checks Gatekeeper acceptance, and creates `Clipboard-Remix-0.1.0-arm64.zip` plus its SHA-256 checksum. It never publishes a GitHub Release automatically.

Use `NOTARY_PROFILE` to choose a different Keychain profile, `NOTARY_KEYCHAIN` to select its Keychain (default: login), and `CLIPBOARD_BUILD_ROOT` for a different build volume. Signing credentials and private keys never belong in the release directory or repository.

## Before publishing

Test the final ZIP by downloading/extracting it on another Mac, moving the app to Applications, launching normally, and checking screenshot capture and pasting. Current builds are Apple Silicon only with a declared macOS 14 minimum; older OS compatibility still needs a separate test. Review app name, icon, version, and release notes before a public launch.
