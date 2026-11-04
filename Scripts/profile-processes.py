#!/usr/bin/env python3
"""Read-only per-process CPU/RSS sampling; makes no energy-use inference."""
import argparse
import csv
from datetime import datetime
import json
from pathlib import Path
import subprocess
import time
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {'Original': '/Applications/Stats.app/Contents/MacOS/Stats',
            'Trio': str(ROOT / 'build/Stats Trio.app/Contents/MacOS/StatsTrio')}


def cpu_seconds(value):
    days = 0
    if '-' in value:
        days, value = value.split('-', 1)
    total = float(days) * 86400
    seconds = 0
    for field in value.split(':'):
        seconds = seconds * 60 + float(field)
    return total + seconds


def snapshot():
    output = subprocess.check_output(['ps', '-axo', 'pid=,time=,rss=,command='], text=True)
    found = {}
    for line in output.splitlines():
        parts = line.strip().split(None, 3)
        if len(parts) != 4:
            continue
        for label, command in EXPECTED.items():
            if parts[3] == command or parts[3].startswith(command + ' '):
                found[label] = (int(parts[0]), cpu_seconds(parts[1]), int(parts[2]))
    return found


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--duration', type=float, default=300)
    parser.add_argument('--interval', type=float, default=5)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.duration <= 0 or args.interval <= 0:
        parser.error('duration and interval must be positive')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    previous, observations = {}, {'Original': [], 'Trio': []}
    began = time.monotonic()
    with args.output.open('w') as handle:
        writer = csv.writer(handle)
        writer.writerow(['time_Asia_Shanghai', 'elapsed_s', 'label', 'pid', 'cpu_percent', 'rss_kib'])
        while True:
            now = time.monotonic()
            for label, (pid, cpu, rss) in snapshot().items():
                percent = None
                prior = previous.get(label)
                if prior and prior[0] == pid:
                    percent = max(0, (cpu - prior[1]) / (now - prior[2]) * 100)
                    observations[label].append((percent, rss))
                previous[label] = (pid, cpu, now)
                writer.writerow([datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(), round(now - began, 2),
                                 label, pid, '' if percent is None else round(percent, 3), rss])
            handle.flush()
            remaining = args.duration - (time.monotonic() - began)
            if remaining <= 0:
                break
            time.sleep(min(args.interval, remaining))
    summary = {}
    for label, rows in observations.items():
        summary[label] = {
            'samples': len(rows),
            'mean_cpu_percent': round(sum(row[0] for row in rows) / len(rows), 3) if rows else None,
            'peak_cpu_percent': round(max(row[0] for row in rows), 3) if rows else None,
            'min_rss_mib': round(min(row[1] for row in rows) / 1024, 2) if rows else None,
            'max_rss_mib': round(max(row[1] for row in rows) / 1024, 2) if rows else None,
        }
    args.output.with_suffix('.json').write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
