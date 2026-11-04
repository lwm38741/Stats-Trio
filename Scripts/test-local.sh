#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m unittest discover -s Tests/Integration -p 'test_*.py'
mkdir -p build
xcrun swiftc -swift-version 5 -target arm64-apple-macos15.0 \
    Stats/IntegrationCore/*.swift \
    Vendor/StatusTrio/Sources/StatusTrioCore/Embedding/TrioRuntimeLifecycle.swift \
    Kit/plugins/Repeater.swift \
    Kit/module/NetworkInterfaceSelection.swift Kit/module/NetworkRateSampler.swift \
    Tests/Integration/*.swift -o build/IntegrationTests
build/IntegrationTests "${1:-}"
