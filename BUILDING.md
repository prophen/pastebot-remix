# Building Clipboard Remix

These instructions are for contributors. For application usage, see [README.md](README.md).

## Toolchain

The project uses Swift Package Manager, SwiftUI, AppKit, SQLite, and system frameworks. No third-party package dependencies are downloaded.

The verified build environment is Apple Silicon with Swift 6.4 Command Line Tools and the macOS 26.5 SDK. Full Xcode was not required in that environment. The scripts currently pin this SDK path:

`/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk`

Inspect your environment with:

```sh
swift --version
xcode-select -p
xcrun --show-sdk-path
```

If your SDK is elsewhere, update the `--sdk` argument in `scripts/build.sh` to an installed compatible SDK and verify the build. The default macOS 27 SDK previously exposed a SwiftUI macro unavailable in the tested Command Line Tools environment. Merely changing the path is not a compatibility guarantee.

## Choose an artifact directory

Set an absolute, writable directory on a volume with enough space. On the existing maintainer machine, all build artifacts must remain on the external SSD:

```sh
export CLIPBOARD_BUILD_ROOT="/Volumes/Expansion/pastebot-remix-build"
```

On another machine, set this variable to your own artifact directory. If omitted, the script uses the path above and requires Expansion to be mounted. Compiler caches, SwiftPM output, and test fixtures are placed under the build root.

This setting controls **build outputs only**. The current app still has runtime path restrictions for login registration and drag exports; see the [public-release prerequisites](RELEASE.md#public-release-prerequisites).

## Build and launch

From the repository root:

```sh
./scripts/build.sh
open "$CLIPBOARD_BUILD_ROOT/Clipboard Remix.app"
```

The build assembles an ad-hoc-signed application. It is suitable for development, not a notarized public download. Quit another running copy before launching a different build.

Application history normally uses your real account’s Application Support folder. For automated tests, use the test command below; never clear real history to prepare a test.

## Test

```sh
./scripts/build.sh test
```

The standalone core harness and a test-only app build run without XCTest. Native checks briefly display test palettes. They use isolated preferences, named pasteboards, and temporary fixtures under the explicit `CLIPBOARD_TEST_ROOT` set by the script; do not run the test binaries directly without that environment.

See [TESTING.md](TESTING.md) for coverage and manual checks.

## Installation helper

`scripts/install.sh` is currently a **maintainer-only helper**. It installs into the fixed Expansion path, validates the original project’s Developer ID team, and refuses to overwrite an existing destination. It is not a general installer for forks or end users. Do not relax its signing requirement simply to install an unrelated app.

For distributable builds and normal user installation, follow [RELEASE.md](RELEASE.md) after resolving its portability prerequisites.
