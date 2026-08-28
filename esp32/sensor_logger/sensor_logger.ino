#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoOTA.h>
#include <esp_task_wdt.h>
#include <esp_idf_version.h>

// Replace these before the first USB upload.
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char* OTA_PASSWORD = "CHANGE_ME";
const char* FW_VERSION = "logger-1.0.0";

constexpr uint8_t TRIG_PIN = 16;
constexpr uint8_t ECHO_PIN = 18;
constexpr unsigned long SAMPLE_INTERVAL_MS = 1000;
constexpr unsigned long WIFI_CHECK_INTERVAL_MS = 10000;
constexpr unsigned long PULSEIN_TIMEOUT_US = 26000;

WebServer server(80);
unsigned long lastSampleMs = 0;
unsigned long lastWifiCheckMs = 0;
unsigned long sampleNumber = 0;
unsigned long lastDurationUs = 0;
float lastDistanceCm = -1.0f;
bool otaUpdateInProgress = false;

float distanceFromDuration(unsigned long durationUs) {
  return durationUs * 0.0343f / 2.0f;
}

void takeSample() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  lastDurationUs = pulseIn(ECHO_PIN, HIGH, PULSEIN_TIMEOUT_US);
  lastDistanceCm = lastDurationUs == 0
      ? -1.0f
      : distanceFromDuration(lastDurationUs);
  sampleNumber++;
  lastSampleMs = millis();

}

void sendReading() {
  static char body[192];
  if (sampleNumber == 0) {
    snprintf(body, sizeof(body),
             "{\"sample\":null,\"millis\":null,\"duration_us\":null,\"distance_cm\":null,\"fw\":\"%s\"}",
             FW_VERSION);
  } else {
    snprintf(body, sizeof(body),
             "{\"sample\":%lu,\"millis\":%lu,\"duration_us\":%lu,\"distance_cm\":%s,\"fw\":\"%s\"}",
             sampleNumber,
             lastSampleMs,
             lastDurationUs,
             lastDurationUs == 0 ? "null" : String(lastDistanceCm, 2).c_str(),
             FW_VERSION);
  }
  server.send(200, "application/json", body);
}

void sendPing() {
  static char body[64];
  snprintf(body, sizeof(body), "{\"status\":\"ok\",\"fw\":\"%s\"}", FW_VERSION);
  server.send(200, "application/json", body);
}

void onOtaStart() {
  otaUpdateInProgress = true;
}

void onOtaEnd() {
  otaUpdateInProgress = false;
}

void onOtaError(ota_error_t) {
  otaUpdateInProgress = false;
}

void setup() {
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

#if ESP_IDF_VERSION_MAJOR >= 5
  esp_task_wdt_config_t watchdogConfig = { .timeout_ms = 30000, .idle_core_mask = 0, .trigger_panic = true };
  esp_task_wdt_init(&watchdogConfig);
#else
  esp_task_wdt_init(30, true);
#endif
  esp_task_wdt_add(NULL);

  WiFi.persistent(true);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  const unsigned long started = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - started < 15000) {
    delay(100);
  }

  ArduinoOTA.setHostname("tank-sensor-logger");
  ArduinoOTA.setPassword(OTA_PASSWORD);
  ArduinoOTA.onStart(onOtaStart);
  ArduinoOTA.onEnd(onOtaEnd);
  ArduinoOTA.onError(onOtaError);
  ArduinoOTA.begin();

  server.on("/ping", HTTP_GET, sendPing);
  server.on("/reading", HTTP_GET, sendReading);
  server.begin();

}

void loop() {
  esp_task_wdt_reset();
  server.handleClient();
  ArduinoOTA.handle();

  const unsigned long now = millis();
  if (now - lastWifiCheckMs >= WIFI_CHECK_INTERVAL_MS) {
    lastWifiCheckMs = now;
    if (!otaUpdateInProgress && WiFi.status() != WL_CONNECTED) {
      WiFi.reconnect();
    }
  }

  if (now - lastSampleMs >= SAMPLE_INTERVAL_MS) {
    takeSample();
  }
}
