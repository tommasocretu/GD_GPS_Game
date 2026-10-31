#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/build/android"
APK="$OUT_DIR/gps-game-debug.apk"

mkdir -p "$OUT_DIR"

flatpak run org.godotengine.Godot \
  --headless \
  --path "$ROOT_DIR" \
  --export-debug "Android" "$APK"

if [[ ! -f "$APK" ]]; then
  echo "Build fallita: $APK non trovato" >&2
  exit 1
fi

ls -lh "$APK"
echo "APK pronto: $APK"
