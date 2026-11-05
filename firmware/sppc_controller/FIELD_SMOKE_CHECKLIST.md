# SPPC ESP32 field smoke checklist

Flash `SPPC_ESP32_Controllermeow.ino`, then verify with the kiosk app on UAT.

## Temperature

- [ ] Start Well Being → Temperature
- [ ] Complete screen shows **°F as the large primary value**
- [ ] **°C appears underneath**
- [ ] Reference hint mentions ~97–99 °F (36.1–37.2 °C)

## Oxygen / SpO2

- [ ] Place finger; keep still for the full collection (and any extend)
- [ ] First good run returns **both heart rate and SpO2**
- [ ] Serial log shows `[MAX] complete bpmCount=… spo2Count=…`
- [ ] If SpO2 was missing historically: confirm extend status `spo2_extending` can appear
- [ ] App never shows a success card with SpO2 as “—” (incomplete → auto-retry once, then idle retry)

## Phone charging

- [ ] Home → Phone Charging → sponsored ad plays
- [ ] After ad: socket arms (“Socket armed — plug in your phone”)
- [ ] Plug phone → “Phone connected” + live V/mA/W
- [ ] Unplug / full / timeout turns socket off and shows Done

## Print tray (shutter + roller)

- [ ] Any print feature (OTP / DigiLocker / Quick / Well Being / Astrology)
- [ ] After job is sent: ESP receives `{"print":"start"}` (shutter opens, roller runs after delay)
- [ ] After USB-verified success: `{"print":"done"}` (roller stops, shutter closes)
- [ ] Cancel or fail mid-print: `{"print":"stop"}` closes tray

## Notes

- Print continues even if the ESP serial port is disconnected (tray commands are skipped with a log).
- Charging / vitals / print tray should not run as concurrent user sessions on one controller.
