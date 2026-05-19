# Omiiba Connect

Unofficial macOS companion for **Sony WH-1000XM3**, based on [Plutoberth/SonyHeadphonesClient](https://github.com/Plutoberth/SonyHeadphonesClient) with extended protocol support from [Gadgetbridge](https://github.com/Freeyourgadget/Gadgetbridge).

**This app is not affiliated with Sony.**

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
- WH-1000XM3 paired with your Mac for audio; use **Connect** in the app for the vendor settings channel

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
