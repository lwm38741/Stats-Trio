#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcrun swiftc -swift-version 6 -target arm64-apple-macos15.0 \
    -F build/Frameworks -I build/ClangModules -framework TrioEmbedded \
    -Xlinker -rpath -Xlinker "$PWD/build/Frameworks" \
    Tests/EmbeddedLayout/main.swift -o build/WiFiLayoutTests
build/WiFiLayoutTests
