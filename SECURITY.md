# Security model — preview, not audited

The expression is a password, not a mathematical answer. No default password is compiled into the app. Short calculator expressions have low entropy; use a long private expression and test files. This preview has not received independent security review.

## Container format v1

`vault.ccv` is a JSON envelope containing version=1, iterations=210000, a 16-byte random salt and a base64 SecretBox concatenation (12-byte nonce, ciphertext, 16-byte GCM tag). AES-256-GCM uses AAD `CipherCalc/v1`. PBKDF2-HMAC-SHA256 derives 256 key bits from the exact UTF-8 expression. Nonces are generated fresh by the cryptography library for every rewrite. The encrypted payload contains all file IDs, names and base64 contents. Ciphertext length and the existence of a vault are visible.

Changes encrypt a complete new container, flush a temporary file, then rename it over the old container. Failed authentication never replaces data. This is not a proven power-loss-safe database: parent-directory metadata is not explicitly synced. No concurrent process access or cross-device container import is supported.

## Locking and plaintext

The UI invalidates outstanding unlock attempts on lock; the storage layer checks a session generation before exposing decrypted data. The key reference and file list are dropped, with best-effort overwrite of key bytes. Dart/Flutter and native code can retain copies: guaranteed zeroization is not claimed. Plaintext exists in RAM while unlocked and during explicitly requested file operations.

Every calculator '=' still computes. Expressions of at least five characters also attempt vault decryption when permitted. After failures the UI applies a one-second delay, rising to 30 seconds after five failures. This state is ephemeral and is not an offline-attack defense.

Non-resumed app states cover the view and normally lock. Import/export system pickers receive at most 30 seconds of grace to complete; afterward the session is invalidated. A short grace period deliberately trades strict immediate locking for usable file selection. It is documented, not an undisclosed exception. UI tests alone cannot prove OS snapshot behavior.

## Outside protection

- Original imported files and OS document-picker caches; the app does not delete them.
- Exported plaintext copies, clipboard text selected in a preview, screenshots and screen recordings.
- Device compromise, rooted/jailbroken environments, live memory capture or another person using an unlocked vault.
- Offline guessing of a weak expression against copied ciphertext.
- Deletion recovery from flash and loss after uninstall, corrupted storage or forgotten passwords.
- OS backups: Android allowBackup is disabled in generated app metadata, subject to platform behavior; iOS backup behavior is not specially overridden. Backup copies may contain the encrypted container.

No application networking, telemetry or account backend is implemented. OS file pickers can access cloud providers selected by the user; export to those providers sends plaintext outside the app. File size/count limits reduce memory use but image decoding can still expand compressed input significantly.

## Build signing

Android previews use the generated Flutter debug signing configuration. It is not a maintained private release-signing identity; changes may require uninstalling the previous preview. Never commit signing keys. iOS preview IPAs are explicitly unsigned, contain no certificate/profile, and are not directly installable. Legitimate personal-device signing is a separate step.

Report bugs in GitHub issues using synthetic examples. Never post a real vault, password, private photo or signing key. Prefer private reporting if a vulnerability affects actual users.
