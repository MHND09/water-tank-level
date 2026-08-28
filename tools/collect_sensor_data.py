"""Collect raw readings from the ESP32 sensor logger over HTTP."""

import argparse
import csv
import json
import sys
import time
from datetime import datetime, timezone
from urllib.error import URLError
from urllib.request import urlopen


FIELDNAMES = [
    "collected_at",
    "sample",
    "millis",
    "duration_us",
    "distance_cm",
    "result",
]


def fetch_reading(url: str, timeout: float) -> dict:
    with urlopen(url, timeout=timeout) as response:
        return json.load(response)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Save raw readings from esp32/sensor_logger over HTTP."
    )
    parser.add_argument(
        "--url",
        default="http://192.168.1.12/reading",
        help="Logger reading endpoint (default: %(default)s)",
    )
    parser.add_argument(
        "--output",
        default="sensor_readings.csv",
        help="CSV output path (default: %(default)s)",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=1.0,
        help="Seconds between polls (default: %(default)s)",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=5.0,
        help="HTTP timeout in seconds (default: %(default)s)",
    )
    args = parser.parse_args()

    if args.interval <= 0 or args.timeout <= 0:
        parser.error("--interval and --timeout must be greater than zero")

    endpoint = args.url.rstrip("/")
    last_sample = None

    print(f"Collecting {endpoint}", file=sys.stderr)
    print(f"Writing {args.output}; press Ctrl+C to stop", file=sys.stderr)

    with open(args.output, "a", newline="", encoding="utf-8") as output_file:
        writer = csv.DictWriter(output_file, fieldnames=FIELDNAMES)
        if output_file.tell() == 0:
            writer.writeheader()
            output_file.flush()

        try:
            while True:
                started = time.monotonic()
                try:
                    reading = fetch_reading(endpoint, args.timeout)
                    sample = reading.get("sample")
                    if sample is not None and sample != last_sample:
                        writer.writerow(
                            {
                                "collected_at": datetime.now(timezone.utc).isoformat(),
                                "sample": sample,
                                "millis": reading.get("millis", ""),
                                "duration_us": reading.get("duration_us", ""),
                                "distance_cm": reading.get("distance_cm", ""),
                                "result": "timeout"
                                if reading.get("duration_us") == 0
                                else "echo",
                            }
                        )
                        output_file.flush()
                        last_sample = sample
                        print(
                            f"sample={sample} distance_cm={reading.get('distance_cm')}",
                            file=sys.stderr,
                        )
                except (OSError, URLError, ValueError, json.JSONDecodeError) as error:
                    print(f"read failed: {error}", file=sys.stderr)

                elapsed = time.monotonic() - started
                time.sleep(max(0.0, args.interval - elapsed))
        except KeyboardInterrupt:
            print("\nCollection stopped", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
