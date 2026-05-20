# Regressie-checklist (WH-1000XM3 / XM4, v1 protocol)

Gebruik na elke wijziging aan NC/ASM, EQ, VPT of general settings. Test op **normaal volume** (~50%) met muziek aan.

## Code-isolatie (audit v2.3.11)

| Functie | Codepad | Geraakt door VPT-fix? |
|---------|---------|------------------------|
| Ambient / NC / focus | `setChanges` blok 1, v1/v2 serializers | Nee — eigen `if`, eigen `fulfill` |
| EQ preset / manual | `hasPendingEqChanges` + EQ commands | Nee — na ambient/VPT-blok |
| Touch sensor | `serializeTouchSensor`, DATA_MDR | Nee |
| Voice guidance | `serializeVoiceGuidance`, DATA_MDR_NO2 | Nee |
| Surround / sound position | VPT-blok + read-back + retry (max 3×) | Ja — alleen dit |

`updateHeadphones` retry stopt pas als virtual sound **én** ambient **én** EQ niet meer pending zijn (elk blok in `setChanges` blijft apart).

**Virtual sound UI:** popups alleen bijwerken als `!hasPendingVirtualSoundChanges()`; bij wissel surround/position direct in de handler (niet wachten op read-back).

## Noise / ambient

- [ ] **Ambient uit** (checkbox uit): duidelijk NC-gevoel
- [ ] **Ambient aan** (checkbox aan), slider **laag (3)** vs **hoog (19)**: duidelijk verschil buitengeluid (test ~50% volume)
- [ ] Slider na wijziging: waarde blijft staan na refresh (geen reset naar oude stand)
- [ ] **Focus on Voice**: alleen beschikbaar bij ambient aan en slider **> 2**; aan/uit verandert stemmen vs omgeving
- [ ] **Refresh**: status komt terug (checkbox, slider, focus) zonder vreemde sprongen

## Virtual sound

- [ ] **Surround**: keuze wisselen (bijv. Off → Arena → Club) — blijft staan na refresh
- [ ] **Surround → sound position**: na Arena/Club, kies Front — hoort positie-effect
- [ ] **Sound position daarna**: wissel Front Right → Rear Left → Front Left (3+ stappen) — elke stap hoorbaar
- [ ] **Sound position → surround**: terug naar Arena — position uit, surround aan

## Equalizer

- [ ] Preset (bijv. Bass Boost) hoorbaar t.o.v. Off
- [ ] Manual EQ: slider wijziging hoorbaar

## Device settings (los van NC-pad)

- [ ] **Touch sensor panel**: uit — touchpad reageert niet; aan — wel (play/pause, volume)
- [ ] **Voice guidance**: uit — geen power/connect-spraak; aan — wel bij power/connect

## Verbinding

- [ ] Connect → refresh toont battery, codec, firmware
- [ ] Disconnect / reconnect zonder crash

## Wat niet in één packet zit (bewust)

Touch sensor en voice guidance gebruiken **eigen** commando’s (`0xd8` / table2 `0x48`); wijzigingen aan ambient/NC raken die paden niet.
