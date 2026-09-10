#!/data/data/com.termux/files/usr/bin/bash
# Görsel önizleme: xvfb + llvmpipe (native software GL) ile portrait render
# KARAR (2026-09-10): Görsel önizleme KULLANICI tarafında yapılır.
# Bu script yalnızca istenirse manuel çalıştırılır; ajan akışında çağrılmaz.
# APK derlemesi GitHub Actions CI'da yapılır (Termux'ta Gradle yok — ev kuralı 4).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tmp
OUT="${1:-tmp/preview.png}"
xvfb-run -a -s "-screen 0 1080x1920x24" \
  env LIBGL_ALWAYS_SOFTWARE=1 \
  ./tools/godot --path . --rendering-driver opengl3 --resolution 1080x1920 \
  -- --screenshot "$OUT"
echo "Önizleme kaydedildi: $OUT"
mkdir -p ~/storage/documents
cp -f "$OUT" ~/storage/documents/ 2>/dev/null || true
