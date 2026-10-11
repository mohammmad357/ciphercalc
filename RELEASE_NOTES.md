# CipherCalc — first file-install preview

Offline Flutter calculator with a user-configured exact-expression unlock and encrypted local file vault. Includes import/list/delete/export, image and small-text preview, background locking, capacity limits and automated parser/storage/widget tests.

**Android:** `CipherCalc-android-preview.apk` is release-mode code signed with the generated preview/debug key. It can be installed outside Play Store. Future builds may have another signing key and require uninstalling; export needed data first.

**iOS:** `CipherCalc-ios-UNSIGNED.ipa` contains the compiled iOS app **without signing or provisioning**. Downloading does not install it. Personal-device installation requires legitimate signing, such as an appropriate Xcode development setup; free Apple provisioning has limitations and expiry. No installable signed iOS release is claimed.

SHA-256 checksum files, resolved dependency locks and Flutter toolchain versions accompany the downloads. Both build jobs must pass analysis and tests before this release is created.

This is a test-file preview, not an independently audited vault. Short expressions are weak; originals, OS picker caches and exported plaintext remain outside protection. No password recovery. Uninstalling can erase data. Physical-device validation remains pending; see MANUAL_TESTS.md.

No store publishing or paid service is required by this repository. Prepared with AI coding assistance. MIT licensed.
