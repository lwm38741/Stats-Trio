#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixture="$PWD/build/PopupFixture.app"
mkdir -p "$fixture/Contents/MacOS"
python3 - "$fixture" <<'PY'
import plistlib, sys
from pathlib import Path
p=Path(sys.argv[1])/'Contents/Info.plist'
p.write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.statstrio.popuptests', 'CFBundleExecutable':'PopupTests', 'LSUIElement':True}))
PY
xcrun swiftc -swift-version 5 -F build/Frameworks -I build/ClangModules -framework Kit \
 -Xlinker -rpath -Xlinker "$PWD/build/Frameworks" Stats/Integration/MenuContentCropping.swift Tests/Popup/main.swift -o "$fixture/Contents/MacOS/PopupTests"
"$fixture/Contents/MacOS/PopupTests"
