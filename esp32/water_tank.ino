#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoOTA.h>
#include <esp_task_wdt.h>
#include <esp_idf_version.h>

// Sensor behaviour (JSN-SR04T, measured on this unit): valid distances down to
// 27.4 cm, below which it does not degrade gracefully but abruptly returns a stuck
// ~18-22 cm artifact regardless of the real distance. That artifact is never a
// distance, but it is meaningful: any echo shorter than BLIND_DISTANCE_CM means the
// surface is closer than the sensor can measure, reported as status "below_range".

const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char* OTA_PASSWORD = "CHANGE_ME";
const char* FW_VERSION = "1.1.0";

constexpr uint8_t TRIG_PIN = 16;
constexpr uint8_t ECHO_PIN = 18;
constexpr unsigned long SENSE_INTERVAL_MS = 3000;
constexpr unsigned long WIFI_CHECK_INTERVAL_MS = 10000;
constexpr unsigned long STALE_AFTER_MS = 15000;
constexpr unsigned long PULSEIN_TIMEOUT_US = 26000;
constexpr float BLIND_DISTANCE_CM = 27.4f;
constexpr float MAX_RANGE_CM = 450.0f;
constexpr size_t MEDIAN_WINDOW = 5;
constexpr uint8_t BLIND_CONFIRM_SAMPLES = 3;

WebServer server(80);
float readings[MEDIAN_WINDOW];
size_t readingCount = 0;
unsigned long lastSampleMs = 0;
unsigned long lastSenseMs = 0;
unsigned long lastWifiCheckMs = 0;
uint8_t blindStreak = 0;
float lastBlindRawCm = -1.0f;

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
  lastSampleMs = millis();
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
  static char body[192];
  if (lastSampleMs == 0) {
    snprintf(body, sizeof(body),
             "{\"distance_cm\":null,\"raw_cm\":null,\"age_s\":null,\"status\":\"no_reading\",\"blind_cm\":%.1f,\"fw\":\"%s\"}",
             BLIND_DISTANCE_CM, FW_VERSION);
    server.send(200, "application/json", body);
    return;
  }
  // Order matters: a dead sensor refreshes neither timestamp, so staleness outranks
  // the blind state, and the blind state outranks an empty median buffer so a reboot
  // with a full tank does not report no_reading forever.
  const unsigned long ageMs = millis() - lastSampleMs;
  const bool blindConfirmed = blindStreak >= BLIND_CONFIRM_SAMPLES;
  const char* status;
  if (ageMs > STALE_AFTER_MS) status = "stale";
  else if (blindConfirmed) status = "below_range";
  else if (readingCount == 0) status = "no_reading";
  else status = "ok";

  char distance[16], raw[16];
  if (readingCount > 0 && !blindConfirmed) snprintf(distance, sizeof(distance), "%.1f", medianReading());
  else snprintf(distance, sizeof(distance), "null");
  if (blindConfirmed) snprintf(raw, sizeof(raw), "%.1f", lastBlindRawCm);
  else snprintf(raw, sizeof(raw), "null");

  snprintf(body, sizeof(body),
           "{\"distance_cm\":%s,\"raw_cm\":%s,\"age_s\":%lu,\"status\":\"%s\",\"blind_cm\":%.1f,\"fw\":\"%s\"}",
           distance, raw, ageMs / 1000, status, BLIND_DISTANCE_CM, FW_VERSION);
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
  if (now - lastSenseMs >= SENSE_INTERVAL_MS) {
    lastSenseMs = now;
    const float d = readDistance();
    if (d >= BLIND_DISTANCE_CM && d <= MAX_RANGE_CM) { pushReading(d); blindStreak = 0; }
    else if (d > 0.0f && d < BLIND_DISTANCE_CM) {
      // Blind-zone artifact: not a distance, but proof the surface is above the
      // measurable line. Keep it out of the median, still count it as liveness.
      lastBlindRawCm = d; lastSampleMs = now;
      if (blindStreak < BLIND_CONFIRM_SAMPLES) blindStreak++;
    }
  }
}
