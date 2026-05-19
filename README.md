# Omiiba Connect

Unofficial macOS companion for **Sony WH-1000XM3 / XM4 / XM5 / XM6**, based on [Plutoberth/SonyHeadphonesClient](https://github.com/Plutoberth/SonyHeadphonesClient) with extended protocol support from [Gadgetbridge](https://github.com/Freeyourgadget/Gadgetbridge).

**Repository:** https://github.com/macdirtycow/OmiibaConnect

[![Download latest release](https://img.shields.io/github/v/release/macdirtycow/OmiibaConnect?label=Download)](https://github.com/macdirtycow/OmiibaConnect/releases/latest)
[![Donate](https://img.shields.io/badge/Donate-PayPal-00457C?logo=paypal&logoColor=white)](https://paypal.me/macdirtycow)

**This app is not affiliated with Sony.**

## Download

Get the latest **OmiibaConnect.app** from [Releases](https://github.com/macdirtycow/OmiibaConnect/releases/latest). Unzip, then open the app. If macOS blocks it, right-click → Open once, or run `xattr -cr OmiibaConnect.app` in Terminal.

## Support

If Omiiba Connect is useful to you, consider a donation:

**[paypal.me/macdirtycow](https://paypal.me/macdirtycow)**

## Disclaimer

Use at your own risk. Reverse-engineered protocol support; not endorsed by Sony. See [NOTICE.md](NOTICE.md) for attribution.

## Features

- Noise cancelling and ambient sound (read + write)
- Virtual sound / sound position (read + write)
- Battery, codec, firmware version (read)
- Equalizer presets (read + write)
- Touch sensor and voice guidance toggles (read + write)
- Menu bar quick ambient toggle (existing)

See [docs/device-support.md](docs/device-support.md) for full parity vs the mobile app.

## Requirements

- macOS 11+
- Xcode (to build)
- Supported: **WH-1000XM3**, **WH-1000XM4** (best), **WH-1000XM5** (good), **WH-1000XM6** (partial — see [docs/device-support.md](docs/device-support.md))
- Headphones paired with your Mac for audio; use **Connect headphones** for the vendor settings channel

## Build

```bash
chmod +x scripts/build-macos.sh
./scripts/build-macos.sh
```

Open `build/DerivedData/Build/Products/Release/OmiibaConnect.app`.

## Docs

- [Feature matrix](docs/device-support.md)
- [Sony APK analysis (jadx)](docs/sony-apk-analysis.md)
- [Packet capture / reverse engineering](docs/packet-capture.md)
- [Firmware policy](docs/FIRMWARE.md)
- [Notarization](docs/NOTARIZATION.md)

## License

MIT — see [LICENSE](LICENSE). Includes copyright and license from the upstream SonyHeadphonesClient project.
