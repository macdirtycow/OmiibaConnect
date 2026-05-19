# APK reference — Sony | Sound Connect

## Which APK to use

| File | Size | Protocol useful? |
|------|------|------------------|
| `Headphones-9.5.0.apk` | ~63 MB | **Yes** — full app, `tandemfamily.message.mdr` |
| `com.sony.songpal.mdr_1.0.5-…_apkmirror.com.apk` | ~9 MB | **No** — stub/shell, no MDR enums |

De nieuwste APKMirror-build (1.0.5, mei 2026) bevat **geen** `Command.java` of Bluetooth-protocol. Gebruik voor byte-vergelijking altijd de **grote** Headphones/Sound Connect APK.

Decompile:

```bash
./scripts/analyze-sony-apk.sh ~/Downloads/Headphones-9.5.0.apk
```

## Bron (9.5.0)

`~/Downloads/Headphones-9.5.0.apk`  
→ `tools/apk/decompiled/sources/`

Package: `com.sony.songpal.mdr`

## Connect-reeks (APK 9.5.0, bevestigd)

1. `CONNECT_GET_PROTOCOL_INFO` — `{ 0x00, 0x00 }` (`CommonCapabilityInquiredType.FIXED_VALUE`)
2. `CONNECT_GET_CAPABILITY_INFO` — `{ 0x02, 0x00 }` (zelfde subtype)
3. `CONNECT_GET_SUPPORT_FUNCTION` — `{ 0x06, … }`
4. Daarna o.a. battery `0x10`, codec `0x18`, `NCASM_GET_PARAM` `0x66` + subtype `0x02`

Omiiba Connect voert stap 1–3 uit in `Headphones::performConnectHandshake()`.

## Commando’s table1 (APK enum → Omiiba Connect)

| APK (`Command.java`) | Byte | `Constants.h` / gebruik |
|----------------------|------|------------------------|
| CONNECT_GET_PROTOCOL_INFO | 0x00 | Handshake |
| CONNECT_GET_CAPABILITY_INFO | 0x02 | Handshake (toegevoegd) |
| CONNECT_GET_SUPPORT_FUNCTION | 0x06 | Handshake |
| COMMON_GET_BATTERY_LEVEL | 0x10 | `BATTERY_REQUEST` |
| COMMON_RET_BATTERY_LEVEL | 0x11 | `BATTERY_RET` |
| COMMON_NTFY_BATTERY_LEVEL | 0x13 | `BATTERY_NTFY` |
| COMMON_GET_AUDIO_CODEC | 0x18 | `AUDIO_CODEC_REQUEST` |
| COMMON_RET_AUDIO_CODEC | 0x19 | `AUDIO_CODEC_RET` |
| COMMON_NTFY_AUDIO_CODEC | 0x1b | `AUDIO_CODEC_NTFY` |
| CONNECT_GET_DEVICE_INFO + FW | 0x04 + 0x02 | Firmware |
| VPT_GET_PARAM | 0x46 (70) | Virtual sound (`COMMAND_TYPE::VPT_GET_PARAM`) |
| EQEBB_GET_PARAM | 0x56 | `EQ_GET` + subtype `0x01` |
| NCASM_GET_PARAM | 0x66 | `NCASM_GET` + subtype `0x02` |
| NCASM_RET_PARAM | 0x67 | `NCASM_RET` |
| GENERAL_SETTING_GET_PARAM | 0xD6 | Touch (`GS_INQUIRED_TYPE::GENERAL_SETTING2` = 0xD2) |

Voice guidance: `mdr/v1/table2`, `VOICE_GUIDANCE_GET_PARAM` = `0x46`, `DATA_MDR_NO2`.

## Audio codec bytes (`AudioCodec.java`)

| APK | Byte | Omiiba `ProtocolParser` |
|-----|------|-------------------------|
| SBC | 0x01 | Ja |
| AAC | 0x02 | Ja |
| LDAC | 0x10 | Ja |
| aptX | 0x20 | Ja |
| aptX HD | 0x21 | Ja |

Geen wijziging nodig t.o.v. 9.5.0.

## Laatste verificatie

- **APK 1.0.5** (Downloads, mei 2026): geen protocol — documentatie + script waarschuwing.
- **APK 9.5.0**: alle gebruikte command-bytes komen overeen; extra handshake `0x02` toegevoegd.
