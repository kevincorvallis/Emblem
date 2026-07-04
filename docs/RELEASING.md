# Releasing Emblem

## One-time setup (requires your Apple Developer account)

### 1. Create a Developer ID Application certificate

Your keychain has "Apple Development" and "Apple Distribution" identities;
direct distribution needs a third kind. Easiest path — Xcode:

**Xcode → Settings → Accounts → (your team) → Manage Certificates… → + →
Developer ID Application.**

(Or developer.apple.com → Certificates → + → Developer ID Application; only the
Account Holder role can create these.)

Verify: `security find-identity -v -p codesigning` now lists
`Developer ID Application: Kevin Lee (4F8Q446767)`.

### 2. Store notarization credentials (local releases)

Create an App Store Connect API key (appstoreconnect.apple.com → Users and
Access → Integrations → App Store Connect API → Team Keys → +, role
"Developer"). Download the `.p8` once, note the Key ID and Issuer ID. Then:

```bash
xcrun notarytool store-credentials emblem \
  --key ~/Downloads/AuthKey_XXXXXX.p8 \
  --key-id XXXXXX \
  --issuer YOUR-ISSUER-UUID
```

### 3. GitHub secrets (CI releases)

Repo → Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `MACOS_CERT_P12` | `base64 -i cert.p12` of the Developer ID identity (export from Keychain Access with a password) |
| `MACOS_CERT_PASSWORD` | that export password |
| `NOTARY_KEY_P8` | `base64 -i AuthKey_XXXXXX.p8` |
| `NOTARY_KEY_ID` | the API Key ID |
| `NOTARY_KEY_ISSUER` | the Issuer UUID |

Without these secrets the release workflow still runs, producing an ad-hoc
signed DMG (right-click-to-open required).

## Cutting a release

1. Bump `CFBundleShortVersionString` in `Emblem/App/Info.plist`, update
   `CHANGELOG.md`, commit.
2. `git tag v<version> && git push origin v<version>` — CI builds, signs,
   notarizes, staples, and attaches the DMG to a GitHub Release.

Local equivalent: `NOTARY_PROFILE=emblem ./scripts/build-release.sh`
(auto-detects the Developer ID identity in your keychain).

## Homebrew cask

After the release exists, update `packaging/emblem.rb` with the printed sha256
and push it to a `kevincorvallis/homebrew-tap` repo →
`brew install --cask kevincorvallis/tap/emblem`.
