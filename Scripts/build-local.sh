#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Scripts/build-frameworks.py
python3 Scripts/build-trio.py
python3 Scripts/build-app.py
