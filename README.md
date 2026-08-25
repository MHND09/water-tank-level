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

The app now uses the real HTTP repository. Set the ESP32 address in Settings. For
development without hardware, run `python tools/mock_esp32_server.py` on a computer
on the same WiFi network, then set the app address to that computer's LAN address
and port (for example `http://192.168.1.20:8080`).

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

## Python ESP32 mock

```text
python tools/mock_esp32_server.py
```

The server exposes `/ping` and `/level`. In its terminal, use `+`/Up to increase
distance, `-`/Down to decrease distance, `n` for `no_reading`, `s` for `stale`,
`o` for normal readings, and `q` to stop the server.
