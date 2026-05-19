# WH-1000XM3 feature matrix (Omiiba Connect)

Reference: [Sony Headphones Connect help guide](https://helpguide.sony.net/mdr/wh1000xm3/v1/en/contents/TP0001703107.html).

| Feature | Sony app | Omiiba Connect v2 | Notes |
|---------|----------|-----------------|-------|
| Easy pairing | Yes | No | Phone/NFC flow |
| Battery % | Yes | **Yes** | `BATTERY_LEVEL_REQUEST` (0x10) |
| Bluetooth codec display | Yes | **Yes** | macOS uses SBC/AAC; LDAC not available on Mac |
| NC / Ambient Sound Control | Yes | **Yes** | Read + write |
| Adaptive Sound Control | Yes | No | Needs phone sensors/location |
| NC Optimizer | Yes | Planned | Protocol: 0x84/0x86 (not in v2 UI) |
| Sound position | Yes | **Yes** | Read + write |
| Surround (VPT) | Yes | **Yes** | Read + write |
| Equalizer presets | Yes | **Yes** | Read + write (9 presets) |
| Custom EQ bands | Yes | Partial | Read parsed; manual band UI not yet |
| Sound quality / connection mode | Yes | Partial | DSEE/upsampling commands documented, no UI yet |
| NC/AMBIENT button mapping | Yes | Partial | Protocol known (0xf6+), no UI yet |
| Auto power off | Yes | Partial | Protocol known, no UI yet |
| Volume adjust | Yes | No | Use macOS volume |
| Media transport | Yes | No | Use macOS media keys |
| Connection / settings status | Yes | **Yes** | Refresh status |
| Firmware version display | Yes | **Yes** | Read only |
| Firmware update | Yes | **Deferred** | See [FIRMWARE.md](FIRMWARE.md) |
| Voice guidance language | Yes | Partial | On/off only in v2 |
| Voice guidance on/off | Yes | **Yes** | COMMAND_2 channel |
| Touch sensor on/off | Yes | **Yes** | Read + write |
| Speak-to-chat | Yes | No | Phase 3 / experimental |
| 360 Reality Audio | Yes | No | Streaming service, not BT settings |
| Listening analytics | Yes | No | Sony cloud |

**Legend:** **Yes** = implemented in this fork; Partial = protocol or read-only; No = out of scope or not feasible on Mac.

Protocol bytes are aligned with the Sony APK (`com.sony.songpal.mdr`, package `com.sony.songpal.tandemfamily.message.mdr`) — see [sony-apk-analysis.md](sony-apk-analysis.md). Connect handshake (`0x00` / `0x06`) runs before status refresh, matching the official app.
