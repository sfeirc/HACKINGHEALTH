#!/usr/bin/env bash
# Install and run the app on your iPhone.
# 1. Connect the iPhone with USB and unlock it (trust this computer if asked).
# 2. Run from repo root: ./scripts/run-on-iphone.sh
# 3. When Flutter lists devices, type the number for your iPhone (e.g. "2").
# Mac and iPhone must be on the same Wi‑Fi; set your Mac IP in apps/mobile/lib/core/constants/api_config_io.dart (_kLanHost).
set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT/apps/mobile"
echo "Waiting for devices (connect your iPhone via USB and unlock it)..."
flutter run --device-timeout=120
