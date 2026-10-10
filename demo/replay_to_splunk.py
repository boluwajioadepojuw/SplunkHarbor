#!/usr/bin/env python3
"""Replay the splunk-replay events into a Splunk HEC endpoint.

Reads the HEC-ready JSONL files in events/ (real Mordor captures plus a
labeled, schema-accurate 4625 burst) and posts them to the HTTP Event
Collector configured by SplunkHarbor. Each event carries its sourcetype,
so the lab's props.conf routing lands Sysmon events in the sysmon index
and Security events in wineventlog.

Usage (from the repo root):

    python3 datasets/splunk-replay/replay_to_splunk.py events_dir         --hec-url https://localhost:8088 --hec-token YOUR_TOKEN [--now]

--now rebases the historical capture timestamps onto the current time so
the shipped saved searches (dispatch.earliest_time=-6m) fire on schedule.
"""

import argparse
import json
import sys
import time
import ssl
import urllib.request
from pathlib import Path


def post_batch(hec_url: str, token: str, payload: str, insecure: bool = False) -> None:
    req = urllib.request.Request(
        hec_url.rstrip("/") + "/services/collector",
        data=payload.encode("utf-8"),
        headers={
            "Authorization": "Splunk " + token,
            "Content-Type": "application/json",
        },
    )
    ctx = ssl._create_unverified_context() if insecure else None
    with urllib.request.urlopen(req, timeout=60, context=ctx) as resp:
        body = resp.read().decode("utf-8", "replace")
    print(body)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("events_dir", help="directory with the JSONL event files")
    parser.add_argument("--hec-url", default="https://localhost:8088")
    parser.add_argument("--hec-token", required=True)
    parser.add_argument("--now", action="store_true",
                        help="rebase event timestamps onto the current time")
    parser.add_argument("--insecure", action="store_true",
                        help="skip TLS verification (lab self-signed cert)")
    args = parser.parse_args()

    events_dir = Path(args.events_dir)
    files = sorted(events_dir.glob("*.jsonl"))
    if not files:
        print("no .jsonl files found under", events_dir, file=sys.stderr)
        return 1

    cursor = time.time()
    total = 0
    for path in files:
        lines = []
        for raw in path.read_text(encoding="utf-8").splitlines():
            if not raw.strip():
                continue
            ev = json.loads(raw)
            if args.now and isinstance(ev.get("time"), (int, float)):
                # sequential timestamps anchored at now (preserves order)
                ev["time"] = cursor
                cursor += 0.02
            lines.append(ev)
        if lines:
            print(f"posting {path.name}: {len(lines)} events")
            post_batch(args.hec_url, args.hec_token,
                       "\n".join(json.dumps(e) for e in lines),
                       insecure=args.insecure)
            total += len(lines)
    print(f"done: {total} events sent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
