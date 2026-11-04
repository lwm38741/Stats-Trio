#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
Scripts/test-local.sh TrioEmbeddedRuntimeTests
xcrun swiftc -swift-version 6 -target arm64-apple-macos15.0 \
    -F build/Frameworks -I build/ClangModules -framework TrioEmbedded \
    -Xlinker -rpath -Xlinker "$PWD/build/Frameworks" \
    Tests/Embedded/main.swift -o build/EmbeddedTests
build/EmbeddedTests
