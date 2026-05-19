# macOS distribution and notarization

## Entitlements

[SonyHeadphonesClient.entitlements](../Client/macos/SonyHeadphonesClient.entitlements) includes:

- `com.apple.security.app-sandbox` — enabled
- `com.apple.security.device.bluetooth` — required for IOBluetooth RFCOMM

## Build release app

```bash
./scripts/build-macos.sh
open build/DerivedData/Build/Products/Release/OmiibaConnect.app
```

## Notarize (for distribution outside your Mac)

1. Enroll in Apple Developer Program.
2. Set `DEVELOPMENT_TEAM` in Xcode or export `DEVELOPER_ID="Developer ID Application: …"`.
3. Sign:

```bash
codesign --deep --force --options runtime \
  --entitlements Client/macos/SonyHeadphonesClient.entitlements \
  --sign "$DEVELOPER_ID" \
  build/DerivedData/Build/Products/Release/OmiibaConnect.app
```

4. Create DMG, notarize with `xcrun notarytool submit`, staple ticket.

App Store distribution is **not** targeted: sandbox + IOBluetooth vendor RFCOMM is a poor fit for review.

## Privacy

`NSBluetoothAlwaysUsageDescription` is set in [info.plist](../Client/macos/info.plist). No analytics or network calls are made by the app core.
