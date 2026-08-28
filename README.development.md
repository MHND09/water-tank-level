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

### Raw sensor data collection

For a diagnostic fill/empty cycle, open `esp32/sensor_logger/sensor_logger.ino` as a
separate Arduino IDE sketch. It uses the same pins and credentials, keeps ArduinoOTA
enabled, and deliberately applies no blind-zone threshold or filtering. At 115200 baud,
the Serial Monitor prints CSV rows:

```text
sample,millis,duration_us,distance_cm,result
```

Save the serial output from before filling until after emptying. The latest raw sample is
also available at `http://<esp32-ip>/reading`. After the experiment, open the original
`esp32/water_tank.ino` and upload it over OTA to restore the monitoring firmware.

If USB is unavailable, run the HTTP collector from a computer on the same WiFi network:

```text
python tools/collect_sensor_data.py --url http://<esp32-ip>/reading --output tank_cycle.csv
```

It polls once per second, skips duplicate samples, flushes each new row to disk, and
continues through temporary request failures. Stop it with `Ctrl+C` after the cycle.

To see the same collected readings live in a browser, use the dashboard server instead
of running the collector separately:

```text
python tools/sensor_dashboard_server.py --url http://<esp32-ip>/reading --output tank_cycle.csv
```

Open `http://127.0.0.1:8080/`. The Python server makes the only `/reading` requests,
writes the CSV, and broadcasts each new sample to the page; the page never contacts the
ESP32 directly.

Keep the ArduinoOTA code in every future firmware upload. Configure a router DHCP
reservation for the ESP32 MAC address at `192.168.1.12`; do not configure a firmware
static IP.

See `docs/water_tank_monitor_technical_spec.md` for wiring, API, and sensor behavior,
and `docs/project_decisions.md` for implementation decisions.

## Python ESP32 mock

```text
python -m pip install -r tools/requirements.txt
python tools/mock_esp32_server.py
```

The server exposes `/ping` and `/level`. In its terminal, use `+`/Up to increase
distance, `-`/Down to decrease distance, `n` for `no_reading`, `s` for `stale`,
`o` for normal readings, and `q` to stop the server.
