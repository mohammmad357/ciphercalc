# Physical-device checklist

Not yet executed by automated CI. Record OS, device, build SHA and outcome before marking any item complete.

- Configure a long expression; verify the exact expression opens, an equal-result expression does not, and ordinary calculations remain usable.
- Import image, text, video and arbitrary binary test files; compare exported bytes with originals.
- Confirm originals remain; cancel pickers; let a picker remain open longer than 30 seconds.
- Lock during password derivation and file import; verify decrypted UI does not reappear.
- Background from a preview, return, and verify calculator/lock state; check app-switcher snapshots.
- Export only after confirmation; test Files/cloud destinations separately and treat copies as plaintext.
- Test empty files, total capacity, long names, malformed images and text preview limits.
- Test deletion cancellation and persistence after restart.
- Test offline operation, low storage, process termination during rewrite and error recovery without replacing the existing container.
- Check large text accessibility, small/landscape screens and screen readers.
- Validate Android install/signature and update behavior before putting important files in a preview.
- Sign the iOS build legitimately for a personal test device; test expiry/re-signing effects without deleting needed files.

Release files prove compilation; they do not prove these device behaviors.
