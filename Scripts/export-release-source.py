#!/usr/bin/env python3
"""Export a tracked source snapshot, excluding machine-specific verification and legacy automation."""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED = ('.github/', 'docs/verification/', 'docs/superpowers/')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    destination = args.destination.resolve()
    if destination.exists() and any(destination.iterdir()):
        parser.error('destination must be empty')
    destination.mkdir(parents=True, exist_ok=True)
    files = subprocess.check_output(['git', 'ls-tree', '-r', '-z', '--name-only', 'HEAD'], cwd=ROOT).split(b'\0')
    for raw in files:
        if not raw:
            continue
        name = raw.decode()
        if name.startswith(EXCLUDED):
            continue
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(subprocess.check_output(['git', 'show', 'HEAD:' + name], cwd=ROOT))
        source = ROOT / name
        if source.stat().st_mode & 0o111:
            target.chmod(0o755)
    (destination / 'README.md').write_bytes((destination / 'docs/distribution/README.md').read_bytes())
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    (destination / 'SOURCE_REVISION').write_text(revision + '\n')
    print('Exported clean source snapshot:', destination)


if __name__ == '__main__':
    main()
