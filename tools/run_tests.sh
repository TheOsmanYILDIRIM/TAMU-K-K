#!/data/data/com.termux/files/usr/bin/bash
# Headless test koşucu — tüm test suite'i CLI'da çalıştırır
set -euo pipefail
cd "$(dirname "$0")/.."
./tools/godot --headless --path . -s tests/run_tests.gd "$@"
