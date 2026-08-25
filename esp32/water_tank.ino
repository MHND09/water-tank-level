#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoOTA.h>
#include <esp_task_wdt.h>
#include <esp_idf_version.h>

const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char* OTA_PASSWORD = "CHANGE_ME";
const char* FW_VERSION = "1.0.0";

constexpr uint8_t TRIG_PIN = 16;
constexpr uint8_t ECHO_PIN = 18;
constexpr unsigned long SENSE_INTERVAL_MS = 3000;
constexpr unsigned long WIFI_CHECK_INTERVAL_MS = 10000;
constexpr unsigned long STALE_AFTER_MS = 15000;
constexpr unsigned long PULSEIN_TIMEOUT_US = 26000;
constexpr float MIN_RANGE_CM = 25.0f;
constexpr float MAX_RANGE_CM = 450.0f;
constexpr size_t MEDIAN_WINDOW = 5;

WebServer server(80);
float readings[MEDIAN_WINDOW];
size_t readingCount = 0;
unsigned long lastGoodMs = 0;
unsigned long lastSenseMs = 0;
unsigned long lastWifiCheckMs = 0;

float readDistance() {
  digitalWrite(TRIG_PIN, LOW); delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  const unsigned long duration = pulseIn(ECHO_PIN, HIGH, PULSEIN_TIMEOUT_US);
  if (duration == 0) return -1.0f;
  return duration * 0.0343f / 2.0f;
}

void pushReading(float value) {
  if (readingCount < MEDIAN_WINDOW) readings[readingCount++] = value;
  else { for (size_t i = 1; i < MEDIAN_WINDOW; i++) readings[i - 1] = readings[i]; readings[MEDIAN_WINDOW - 1] = value; }
  lastGoodMs = millis();
}

float medianReading() {
  if (readingCount == 0) return -1.0f;
  float sorted[MEDIAN_WINDOW];
  for (size_t i = 0; i < readingCount; i++) sorted[i] = readings[i];
  for (size_t i = 0; i < readingCount; i++) for (size_t j = i + 1; j < readingCount; j++) if (sorted[j] < sorted[i]) { float t = sorted[i]; sorted[i] = sorted[j]; sorted[j] = t; }
  return sorted[readingCount / 2];
}

void sendPing() {
  static char body[64];
  snprintf(body, sizeof(body), "{\"status\":\"ok\",\"fw\":\"%s\"}", FW_VERSION);
  server.send(200, "application/json", body);
}

void sendLevel() {
  static char body[128];
  if (readingCount == 0) {
    snprintf(body, sizeof(body),
             "{\"distance_cm\":null,\"age_s\":null,\"status\":\"no_reading\",\"fw\":\"%s\"}",
             FW_VERSION);
  } else {
    const unsigned long ageMs = millis() - lastGoodMs;
    const char* status = (ageMs > STALE_AFTER_MS) ? "stale" : "ok";
    const unsigned long age = ageMs / 1000;
    snprintf(body, sizeof(body),
             "{\"distance_cm\":%.1f,\"age_s\":%lu,\"status\":\"%s\",\"fw\":\"%s\"}",
             medianReading(), age, status, FW_VERSION);
  }
  server.send(200, "application/json", body);
}

void setup() {
  pinMode(TRIG_PIN, OUTPUT); pinMode(ECHO_PIN, INPUT); Serial.begin(115200);
#if ESP_IDF_VERSION_MAJOR >= 5
  esp_task_wdt_config_t watchdogConfig = { .timeout_ms = 30000, .idle_core_mask = 0, .trigger_panic = true };
  esp_task_wdt_init(&watchdogConfig);
#else
  esp_task_wdt_init(30, true);
#endif
  esp_task_wdt_add(NULL);
  WiFi.persistent(true); WiFi.setAutoReconnect(true); WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  const unsigned long started = millis(); while (WiFi.status() != WL_CONNECTED && millis() - started < 15000) delay(100);
  ArduinoOTA.setHostname("tank-sensor"); ArduinoOTA.setPassword(OTA_PASSWORD); ArduinoOTA.begin();
  server.on("/ping", HTTP_GET, sendPing); server.on("/level", HTTP_GET, sendLevel); server.begin();
}

void loop() {
  esp_task_wdt_reset();
  server.handleClient(); ArduinoOTA.handle();
  const unsigned long now = millis();
  if (now - lastWifiCheckMs >= WIFI_CHECK_INTERVAL_MS) { lastWifiCheckMs = now; if (WiFi.status() != WL_CONNECTED) WiFi.reconnect(); }
  if (now - lastSenseMs >= SENSE_INTERVAL_MS) { lastSenseMs = now; const float d = readDistance(); if (d >= MIN_RANGE_CM && d <= MAX_RANGE_CM) pushReading(d); }
}
