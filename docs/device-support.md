# Supported Sony headphones (Omiiba Connect)

Same Bluetooth MDR protocol family as Sony | Sound Connect. Detection uses the Bluetooth name and the init handshake (4-byte reply = **MDR v1**, 8-byte = **MDR v2**).

| Model | Protocol | Status in app | Notes |
|-------|----------|---------------|-------|
| **WH-1000XM3** | v1 | **Full** | Primary test target |
| **WH-1000XM4** | v1 | **Full** | Same command set as XM3 ([Gadgetbridge](https://gadgetbridge.org/gadgets/headphones/sony/) highly supported) |
| **WH-1000XM5** | v2 | **Good** | Ambient sound uses v2 commands; no touch sensor in UI (matches Gadgetbridge) |
| **WH-1000XM6** | v2 | **Partial** | Battery + ambient sound; EQ / touch / voice guidance hidden (experimental in Gadgetbridge) |

## Feature matrix (vs Sony mobile app)

| Feature | XM3 / XM4 | XM5 | XM6 |
|---------|----------|-----|-----|
| Battery % | Yes | Yes | Yes |
| Codec / firmware read | Yes | Yes | Yes |
| Ambient sound + level + focus on voice | Yes | Yes | Yes |
| Virtual sound / VPT / position | Yes | Yes | No |
| EQ presets | Yes | Yes | No |
| Touch sensor toggle | Yes | No | No |
| Voice guidance on/off | Yes | Yes | No |

**Legend:** Yes = implemented in Omiiba Connect; No = hidden or not supported on that model.

## Other models

Other Sony headphones that expose the same RFCOMM service (`96CC203E-…`) may work if they speak MDR v1 or v2. Unknown names default to **v1** with a 19-step ambient slider until the handshake reports v2.

## References

- [Gadgetbridge Sony headphones](https://gadgetbridge.org/gadgets/headphones/sony/)
- [Sony APK analysis](sony-apk-analysis.md)
- Protocol handshake: `CONNECT_GET_PROTOCOL_INFO` (`0x00`) then `CONNECT_GET_SUPPORT_FUNCTION` (`0x06`)
