# Aqua Level

Android Flutter app and ESP32 firmware for monitoring one water tank over a local
WiFi network. The ESP32 is expected to receive the DHCP-reserved address
`192.168.1.12`; the app defaults to `http://192.168.1.12` and allows changing it in
Settings.

## Flutter development

```text
flutter pub get
flutter analyze
flutter test
flutter run
```

The first app slice uses a fake repository, so it can be developed without hardware.
The HTTP repository is ready for the ESP32 and a future Python mock server.

## ESP32 development

The Arduino IDE sketch is in `esp32/water_tank.ino`. Install the ESP32 board package,
select the correct ESP32 board and serial port, then replace the WiFi and OTA
placeholder credentials before the first USB upload. The sketch uses only libraries
included with the ESP32 Arduino core.

Keep the ArduinoOTA code in every future firmware upload. Configure a router DHCP
reservation for the ESP32 MAC address at `192.168.1.12`; do not configure a firmware
static IP.

See `docs/water_tank_monitor_technical_spec.md` for wiring, API, and sensor behavior,
and `docs/project_decisions.md` for implementation decisions.
