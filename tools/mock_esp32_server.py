"""Flask-based ESP32 HTTP mock for Aqua Level manual testing."""

from flask import Flask, jsonify
import threading
import time
import os

app = Flask(__name__)
PORT = 8080
BLIND_CM = 27.4
FW = "mock-1.1.0"


class MockState:
    def __init__(self):
        self.distance_cm = 55.0
        self.status = "ok"
        self.updated_at = time.monotonic()
        self.lock = threading.Lock()

    def adjust(self, delta):
        with self.lock:
            self.distance_cm = max(5.0, min(450.0, self.distance_cm + delta))
            # Crossing the blind line switches the reported status the way the
            # firmware does: no distance, just "the surface is above my range".
            self.status = "below_range" if self.distance_cm < BLIND_CM else "ok"
            self.updated_at = time.monotonic()

    def set_status(self, status):
        with self.lock:
            self.status = status
            if status in ("ok", "below_range"):
                self.updated_at = time.monotonic()

    def level(self):
        with self.lock:
            age = int(time.monotonic() - self.updated_at)
            distance = round(self.distance_cm, 1)
            status = self.status
        if status == "no_reading":
            return {"distance_cm": None, "raw_cm": None, "age_s": None,
                    "status": status, "blind_cm": BLIND_CM, "fw": FW}
        if status == "below_range":
            # Stuck artifact the real sensor emits below the blind line.
            return {"distance_cm": None, "raw_cm": 20.4, "age_s": age,
                    "status": status, "blind_cm": BLIND_CM, "fw": FW}
        if status == "stale":
            age = max(age, 16)
        return {"distance_cm": distance, "raw_cm": None, "age_s": age,
                "status": status, "blind_cm": BLIND_CM, "fw": FW}


state = MockState()


@app.get("/ping")
def ping():
    return jsonify(status="ok", fw=FW)


@app.get("/level")
def level():
    return jsonify(state.level())


def keyboard_loop():
    print("Controls: +/Up increase, -/Down decrease, n no_reading, s stale, b below_range, o ok, q quit")
    if os.name == "nt":
        import msvcrt
        while True:
            key = msvcrt.getwch()
            if key in ("\x00", "\xe0"):
                key = msvcrt.getwch()
                if key == "H": state.adjust(5)
                elif key == "P": state.adjust(-5)
                else: continue
            elif key in ("+", "="): state.adjust(5)
            elif key in ("-", "_"): state.adjust(-5)
            elif key in ("n", "N"): state.set_status("no_reading")
            elif key in ("s", "S"): state.set_status("stale")
            elif key in ("b", "B"): state.set_status("below_range")
            elif key in ("o", "O"): state.set_status("ok")
            elif key in ("q", "Q"): os._exit(0)
            else: continue
            print(state.level())
    else:
        while True:
            command = input().strip().lower()
            if command in ("+", "up"): state.adjust(5)
            elif command in ("-", "down"): state.adjust(-5)
            elif command == "n": state.set_status("no_reading")
            elif command == "s": state.set_status("stale")
            elif command == "b": state.set_status("below_range")
            elif command == "o": state.set_status("ok")
            elif command == "q": os._exit(0)
            print(state.level())


if __name__ == "__main__":
    threading.Thread(target=keyboard_loop, daemon=True).start()
    print(f"Mock ESP32 listening on http://0.0.0.0:{PORT}")
    app.run(host="0.0.0.0", port=PORT, threaded=True, use_reloader=False)
