# Firmware updates — explicitly out of scope for v2

Sony distributes WH-1000XM3 firmware only through **Sony | Sound Connect** on iOS/Android. Transfer uses large `LARGE_DATA_COMMON` frames over the same Bluetooth service.

## Why this fork does not ship firmware flashing

- **Brick risk** if a transfer is interrupted.
- No widely tested open-source implementation for XM3 on macOS.
- Sony does not document the format for third parties.

## If you need an update

1. Pair the headset with your phone.
2. Update via the official Sony app.
3. Reconnect to your Mac.

## Future (Phase 3 — experimental only)

A future release might add firmware update only when:

- Explicit user opt-in and liability disclaimer.
- Checksum verification and resume support.
- Recovery instructions (recovery mode, re-pair).

Until then, **do not attempt** to port mobile OTA logic without dedicated hardware testing.
