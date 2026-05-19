# APK reference — Headphones 9.5.0

Decompiled from:

`/Users/leopold/Downloads/Headphones-9.5.0.apk`  
→ `tools/apk/decompiled/sources/`

Package: `com.sony.songpal.mdr` (Sony | Sound Connect / Headphones Connect)

## Kernbestanden (table1 = DATA_MDR)

| APK pad | Mac-app |
|---------|---------|
| `.../mdr/v1/table1/Command.java` | Alle `PAYLOAD_CMD` bytes |
| `.../mdr/v1/table1/param/NcAsmInquiredType.java` | NC query subtype `0x02` |
| `.../mdr/v1/table1/param/EqPresetId.java` | `EQ_PRESET` |
| `.../mdr/v1/table1/param/AudioCodec.java` | Codec-weergave (gefixt in v2) |
| `.../mdr/v1/table1/param/generalsetting/GsInquiredType.java` | Touch sensor = `GENERAL_SETTING2` (`0xD2`) |

## table2 = DATA_MDR_NO2 (voice guidance)

| APK | Bytes |
|-----|-------|
| `mdr/v1/table2/Command.java` | `VOICE_GUIDANCE_GET_PARAM` = `0x46` |
| `.../voiceguidance/param/VoiceGuidanceInquiredType.java` | subtype `0x01` |

## Connect-reeks (eerste packets na RFCOMM)

1. `CONNECT_GET_PROTOCOL_INFO` — `0x00`
2. `CONNECT_GET_SUPPORT_FUNCTION` — `0x06`
3. Daarna o.a. `COMMON_GET_BATTERY_LEVEL` (`0x10`), `NCASM_GET_PARAM` (`0x66` + subtype `0x02`)

## Commando’s uit `Command.java` (selectie)

| Enum (APK) | Byte | Status Mac-app |
|------------|------|----------------|
| CONNECT_GET_PROTOCOL_INFO | 0x00 | Handshake |
| COMMON_GET_BATTERY_LEVEL | 0x10 | Ja |
| COMMON_GET_AUDIO_CODEC | 0x18 | Ja (mapping uit APK) |
| CONNECT_GET_DEVICE_INFO | 0x04 | Firmware (`subtype 0x02`) |
| VPT_GET_PARAM / SET | 0x46 / 0x48 | Ja (surround/position) |
| EQEBB_GET_PARAM / SET | 0x56 / 0x58 | Ja |
| NCASM_GET_PARAM / SET | 0x66 / 0x68 | Ja |
| GENERAL_SETTING_GET_PARAM | 0xD6 | Touch (`0xD2`) |
| OPT_SET_STATUS | 0x84 | Gedocumenteerd, UI later |
| AUDIO_GET_PARAM | 0xE6 | DSEE, UI later |
| SYSTEM_GET_PARAM | 0xF6 | Auto-off/knop, UI later |

## Opnieuw decompilen

```bash
./scripts/analyze-sony-apk.sh ~/Downloads/Headphones-9.5.0.apk
open tools/apk/decompiled/sources/com/sony/songpal/tandemfamily/message/mdr/v1/table1/Command.java
```
