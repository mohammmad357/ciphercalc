# CipherCalc

**Everyday numbers. A private space behind your own expression.**

[![Build](https://github.com/mohammmad357/ciphercalc/actions/workflows/build.yml/badge.svg)](https://github.com/mohammmad357/ciphercalc/actions/workflows/build.yml)
[فارسی](README.fa.md) · [Download previews](https://github.com/mohammmad357/ciphercalc/releases) · [Security model](SECURITY.md)

A Flutter calculator for Android and iOS with an offline encrypted file vault. Configure an exact expression, such as `12*16`, clear the display, enter it and press `=` to unlock. The result `192` and the alternative `16*12` do not unlock it. Ordinary expressions still calculate normally.

This is a **v0.1 test-file preview**, prepared with AI coding assistance. Automated tests and compilation are not a security audit or physical-device validation. Do not entrust your only copy of important files to this preview.

## Downloads: no store subscription

Every successful main-branch build publishes files in **GitHub Releases**, separate from source history:

| File | Meaning |
|---|---|
| `CipherCalc-android-preview.apk` | Android release-mode APK, signed with the generated Flutter debug key for this preview |
| `CipherCalc-ios-UNSIGNED.ipa` | Real iOS app bundle packaged as IPA, **without a signature or provisioning profile** |
| `*-SHA256SUMS.txt` | SHA-256 integrity checks for the downloads |
| `*-pubspec.lock`, `*-toolchain.txt` | Resolved dependencies and Flutter build version |

**Android:** download the APK, allow installation from that source when Android asks, then install. This is outside Google Play. The generated preview signing key is not a stable distribution key: later builds may require uninstalling, which can erase vault data. Export any needed files before replacing an installation. A stable private signing key is a future release prerequisite, not committed here.

**iPhone:** downloading an IPA does not make it installable. This unsigned bundle must be signed/provisioned for the destination device using a legitimate Apple development setup. A free Apple account can support limited personal-device testing through Xcode; Apple documents seven-day provisioning expiry. It is not unrestricted public distribution. [Apple account overview](https://developer.apple.com/help/account/basics/about-your-developer-account)

No store submission, paid runner, paid hosting or developer membership is purchased by this project. Public-repository standard GitHub-hosted Actions builds are [free under GitHub's documented policy](https://docs.github.com/en/billing/concepts/product-billing/github-actions). Build availability still depends on GitHub and runner limits.

## What works

- Arithmetic with operator precedence, parentheses, decimals and unary signs; no eval.
- User-configured expression lock, 5–80 characters; use a long private expression. `12*16` is an example, **not a default password**.
- AES-256-GCM authenticated encryption of file contents **and names**. PBKDF2-HMAC-SHA256 derives the key from the exact expression using a random salt and 210,000 iterations.
- Import, list, delete and explicitly export files; in-app image and small-text previews.
- Local-only vault, no account, analytics, ads, cloud sync or application network requests.
- Automatic background locking and invalidation of asynchronous unlocks. System pickers receive a bounded 30-second grace period; the app view is covered while inactive.
- Capacity: **20 MiB total / 200 files**. The vault is an encrypted single-container file; changes rewrite the container.

Imported files are copies. The original and OS picker caches remain outside vault protection. Export creates an unencrypted copy after confirmation. Losing the expression or uninstalling the app can permanently lose vault contents. There is no reset, recovery backdoor or account-based recovery.

## Build from source

Install Flutter stable and the platform SDKs, then from this repo:

```sh
flutter create --project-name ciphercalc --org io.github.mohammmad357 --platforms android,ios generated
```

Replace `generated/lib` and `generated/test` with this repo's `lib` and `test`, and copy `pubspec.yaml` into `generated`. From the repo root:

```sh
python3 tools/configure.py
cd generated
flutter pub get
dart format lib test
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release
```

The workflow contains exact Linux/macOS copy commands. On Windows, use equivalent file-copy operations; Android requires Java and the Android SDK. iOS compilation requires macOS/Xcode; the workflow uses a standard macOS runner and `flutter build ios --release --no-codesign`. To run on a personal iPhone, open the generated Xcode workspace, select your own signing team and configure the device. [Flutter iOS instructions](https://docs.flutter.dev/deployment/ios)

Native shells are generated at build time, customized by `tools/configure.py`, and not committed. The workflow records actual resolved dependency locks in the release; Flutter's stable channel can move between builds. This is reproducible build automation, **not bit-for-bit reproducibility**. Do not put certificates, private keys or real vault files in the repository.

## Verification and limits

Tests cover arithmetic, malformed input, ciphertext round trips across reopen, exact-expression matching, tamper detection, locked-write rejection, limits and lock-during-unlock races, plus a calculator widget flow. Both platform jobs run analysis and tests before building; publication requires both jobs to succeed. See [Actions](https://github.com/mohammmad357/ciphercalc/actions) for actual run outcomes.

Physical-device checks are still required: import/export on both OSes, picker cancellation and timeout, biometric/keyboard interruptions, background lock, low storage, uninstall behavior and accessibility. Biometric unlock, encrypted backup, video playback, password changes and recovery are not implemented. See [the manual checklist](MANUAL_TESTS.md).

The vault does not promise invisibility from device owners, protection on compromised devices, guaranteed RAM erasure, secure deletion from flash, or prevention of iOS screenshots. The small expression space is the main weakness; rate limiting in the UI does not stop offline guessing against copied ciphertext. Read [SECURITY.md](SECURITY.md) before importing anything.

MIT licensed. Store publishing is deliberately outside this project's scope.
