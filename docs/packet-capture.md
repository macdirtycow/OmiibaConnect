# Packet capture guide (Sony WH-1000XM3)

Use this when adding commands that are not yet in [Constants.h](../Client/Constants.h).

**Primary sources (in order):**

1. **Sony APK** (`com.sony.songpal.mdr`) — decompile with [sony-apk-analysis.md](sony-apk-analysis.md) and `./scripts/analyze-sony-apk.sh`
2. **[mdr-protocol](https://github.com/AndreasOlofsson/mdr-protocol)** — packet table derived from APK enums
3. **[Gadgetbridge PayloadTypeV1](https://github.com/Freeyourgadget/Gadgetbridge/blob/master/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/sony/headphones/protocol/impl/v1/PayloadTypeV1.java)** — validated commands on message type `0x0c` (`DATA_MDR`)

**Handshake:** the official app always sends `CONNECT_GET_PROTOCOL_INFO` (`0x00`) first; Omiiba Connect does the same in `Headphones::performConnectHandshake()`.

## Android (recommended)

1. Enable **Developer options** → **Bluetooth HCI snoop log**.
2. Open **Sony | Sound Connect**, connect XM3, change one setting (e.g. EQ).
3. Pull log: `adb pull /sdcard/Android/data/com.android.bluetooth/files/btsnoop_hci.log`
4. Open in Wireshark → filter `btatt` / RFCOMM / follow stream for service UUID `96cc203e-5068-46ad-b32d-e316f5e069ba`.
5. Frames are wrapped: `>` + escaped payload + `<` (see [CommandSerializer.cpp](../Client/CommandSerializer.cpp)).

## Linux

```bash
sudo btmon -w /tmp/xm3.snoop
# use Sony app on phone or this Mac client, then Ctrl+C
wireshark /tmp/xm3.snoop
```

## macOS

System Bluetooth snoop is limited. Prefer:

- Capture from Android, or
- Log hex in this app by extending `BluetoothWrapper::sendQuery` debug prints during development.

## Command map (v1 / XM3)

| Intent | Request bytes | Ret byte | Channel |
|--------|---------------|----------|---------|
| Protocol info (required first) | `00` | `01` | DATA_MDR |
| Support function | `06` | `07` | DATA_MDR |
| Battery | `10 00` | `11` | DATA_MDR |
| Codec | `18 00` | `19` | DATA_MDR |
| Firmware | `04 02` | `05` | DATA_MDR |
| NC/ASM get | `66 02` | `67` | DATA_MDR |
| NC/ASM set | `68 …` | `69` notify | DATA_MDR |
| EQ get | `56` | `57` | DATA_MDR |
| EQ set | `58 …` | `59` notify | DATA_MDR |
| VPT/sound get | `46 01` or `46 02` | `47` | DATA_MDR |
| Touch get | `d6 d2` | `d7` | DATA_MDR |
| Voice get | `46 01 01` | `47` | DATA_MDR_NO2 (14) |

## Adding a new feature

1. Capture request/response pair for one toggle in the official app.
2. Add `PAYLOAD_CMD` in `Constants.h`.
3. Add parser in `ProtocolParser.cpp` and query in `Headphones::refreshFromDevice()`.
4. Update [device-support.md](device-support.md).
