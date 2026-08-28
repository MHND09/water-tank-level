"""Poll the ESP32 once and stream the same readings to CSV and a browser."""

import argparse
import csv
import json
import sys
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from collect_sensor_data import FIELDNAMES, fetch_reading


ROOT = Path(__file__).resolve().parent
HTML = (ROOT / "sensor_dashboard.html").read_bytes()
clients = set()
clients_lock = threading.Lock()


def csv_row(reading: dict) -> dict:
    return {
        "collected_at": datetime.now(timezone.utc).isoformat(),
        "sample": reading.get("sample", ""),
        "millis": reading.get("millis", ""),
        "duration_us": reading.get("duration_us", ""),
        "distance_cm": reading.get("distance_cm", ""),
        "result": "timeout" if reading.get("duration_us") == 0 else "echo",
    }


def broadcast(reading: dict) -> None:
    message = f"data: {json.dumps(reading, separators=(',', ':'))}\n\n".encode()
    with clients_lock:
        current_clients = tuple(clients)
    disconnected = []
    for client in current_clients:
        try:
            client.wfile.write(message)
            client.wfile.flush()
        except OSError:
            disconnected.append(client)
    if disconnected:
        with clients_lock:
            for client in disconnected:
                clients.discard(client)


class DashboardHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path in ("/", "/index.html"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(HTML)
            return

        if self.path == "/events":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.end_headers()
            with clients_lock:
                clients.add(self)
            try:
                while True:
                    self.wfile.write(b": connected\n\n")
                    self.wfile.flush()
                    time.sleep(15)
            except (BrokenPipeError, ConnectionResetError, OSError):
                with clients_lock:
                    clients.discard(self)
            return

        self.send_error(404)

    def log_message(self, format_string: str, *args: object) -> None:
        return


def collect(endpoint: str, output: str, interval: float, timeout: float) -> None:
    last_sample = None
    with open(output, "a", newline="", encoding="utf-8") as output_file:
        writer = csv.DictWriter(output_file, fieldnames=FIELDNAMES)
        if output_file.tell() == 0:
            writer.writeheader()
            output_file.flush()
        while True:
            started = time.monotonic()
            try:
                reading = fetch_reading(endpoint, timeout)
                sample = reading.get("sample")
                if sample is not None and sample != last_sample:
                    writer.writerow(csv_row(reading))
                    output_file.flush()
                    last_sample = sample
                    broadcast(reading)
                    print(
                        f"sample={sample} distance_cm={reading.get('distance_cm')}",
                        file=sys.stderr,
                    )
            except (OSError, ValueError, json.JSONDecodeError) as error:
                print(f"read failed: {error}", file=sys.stderr)
            elapsed = time.monotonic() - started
            time.sleep(max(0.0, interval - elapsed))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://192.168.1.12/reading")
    parser.add_argument("--output", default="sensor_readings.csv")
    parser.add_argument("--interval", type=float, default=1.0)
    parser.add_argument("--timeout", type=float, default=5.0)
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()
    if args.interval <= 0 or args.timeout <= 0 or args.port <= 0:
        parser.error("interval, timeout, and port must be greater than zero")

    collector = threading.Thread(
        target=collect,
        args=(args.url.rstrip("/"), args.output, args.interval, args.timeout),
        daemon=True,
    )
    collector.start()
    server = ThreadingHTTPServer(("0.0.0.0", args.port), DashboardHandler)
    print(f"Open http://127.0.0.1:{args.port}/ in a browser", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nDashboard stopped", file=sys.stderr)
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
