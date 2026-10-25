# macOS notarization (no Gatekeeper warnings)

End users see **“Apple could not verify…”** until the DMG is signed with a **Developer ID** and **notarized** by Apple.

## What you need

- [Apple Developer Program](https://developer.apple.com/programs/) membership
- **Developer ID Application** certificate in a `.p12` export
- App-specific password for `notarytool`

## GitHub Actions secrets

| Secret | Value |
|--------|--------|
| `MACOS_CERTIFICATE_BASE64` | Base64 of `.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | P12 password |
| `APPLE_SIGNING_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_ID` | Apple ID email |
| `APPLE_APP_SPECIFIC_PASSWORD` | From appleid.apple.com |
| `APPLE_TEAM_ID` | 10-character team ID |

Add a workflow step before `build-macos-dmg.sh` to import the certificate into a temporary keychain (standard `security import` pattern). With secrets set, `build-macos-dmg.sh` signs both apps and notarizes the DMG.

Without these secrets, releases stay **ad-hoc signed**; users must use **System Settings → Privacy & Security → Open Anyway** once (see `MACOS-INSTALL.txt`).
