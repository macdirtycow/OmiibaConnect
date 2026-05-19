# Sony | Sound Connect APK analysis

Package: **`com.sony.songpal.mdr`** (Google Play: [Sony | Sound Connect](https://play.google.com/store/apps/details?id=com.sony.songpal.mdr)).

Reverse-engineering notes from the APK (and projects that decompiled it) are the most reliable source for command bytes on WH-1000XM3.

## What the APK contains

Interesting protocol code lives under:

```text
com.sony.songpal.tandemfamily.message.mdr
```

Sony obfuscates most class names, but **enums and packet type bytes are often left readable** — that is how [mdr-protocol](https://github.com/AndreasOlofsson/mdr-protocol) and [Gadgetbridge](https://github.com/Freeyourgadget/Gadgetbridge) were built.

Key facts from APK / mdr-protocol:

1. Transport: Bluetooth Classic **RFCOMM**, UUID `96CC203E-5068-46ad-B32D-E316F5E069BA`.
2. Framing: start `0x3e` (`>`), end `0x3c` (`<`), escape `0x3d` — see [CommandSerializer.cpp](../Client/CommandSerializer.cpp).
3. **First packet** after connect: `CONNECT_GET_PROTOCOL_INFO` (`0x00`). Other features may not respond until this handshake ran.
4. Full command table: [mdr-protocol MDR_packets.md](https://github.com/AndreasOlofsson/mdr-protocol/blob/master/MDR_packets.md).

## Decompile the APK on your Mac (jadx)

1. Install jadx (`brew install jadx`).
2. APK in Downloads (bijv. `~/Downloads/Headphones-9.5.0.apk`) — package is `com.sony.songpal.mdr`.
3. Run:

```bash
./scripts/analyze-sony-apk.sh
# or: ./scripts/analyze-sony-apk.sh ~/Downloads/Headphones-9.5.0.apk
```

Extracted reference: [apk-reference.md](apk-reference.md).

Output: `tools/apk/decompiled/` with browsable Java sources.

### Manual search terms in jadx

| Search | Purpose |
|--------|---------|
| `tandemfamily.message.mdr` | Packet builders/parsers |
| `CONNECT_GET_PROTOCOL_INFO` | Init sequence |
| `NC_ASM_GET_PARAM` | Noise cancelling / ambient |
| `EQ_EBB_GET_PARAM` | Equalizer |
| `GENERAL_SETTING_GET_PARAM` | Touch sensor (`0xd2` subtype) |
| `SYSTEM_GET_PARAM` | Auto-off, button mapping |
| `OPT_SET_STATUS` | NC optimizer |
| `AUDIO_GET_PARAM` | DSEE HX |

### Compare with a live capture

APK shows *what can be sent*; **btsnoop** shows *what the app actually sends* for your firmware.

1. Android: Developer options → Bluetooth HCI snoop log.
2. Open Sound Connect, connect XM3, toggle one setting.
3. `adb pull /sdcard/Android/data/com.android.bluetooth/files/btsnoop_hci.log`
4. Wireshark → RFCOMM → payload between `3e` and `3c`.

See [packet-capture.md](packet-capture.md).

## How this Mac app uses APK knowledge

| APK / mdr-protocol | Sony XM3 Mac |
|--------------------|--------------|
| `CONNECT_GET_PROTOCOL_INFO` (0x00) | `Headphones::performConnectHandshake()` before refresh |
| `CONNECT_GET_SUPPORT_FUNCTION` (0x06) | Same handshake |
| `COMMON_GET_BATTERY_LEVEL` (0x10) | Battery refresh |
| `NC_ASM_GET_PARAM` (0x66) | NC/ambient read |
| `EQ_EBB_GET_PARAM` (0x56) | EQ read |
| `GENERAL_SETTING_GET_PARAM` (0xd6) + `0xd2` | Touch sensor |
| `ALERT_*` on message type 0x0e | Voice guidance (`DATA_MDR_NO2`) |

Not yet wired in UI (bytes documented for Phase 2): `OPT_SET_STATUS` (NC optimizer), `AUDIO_GET_PARAM` (DSEE), `SYSTEM_GET_PARAM` (auto-off / NC button).

## Legal

Interoperability research only. This app is **not** affiliated with Sony. Do not redistribute Sony’s APK.
