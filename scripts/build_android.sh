#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/build/android"
APK="$OUT_DIR/gps-game-debug.apk"

export JAVA_HOME="${JAVA_HOME:-$HOME/.local/opt/temurin-17}"
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"

if [[ ! -f "$ROOT_DIR/addons/gps.aar" ]]; then
  echo "Plugin GPS mancante: esegui prima ./scripts/build_gps_plugin.sh" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

flatpak run \
  --env=JAVA_HOME="$JAVA_HOME" \
  --env=ANDROID_HOME="$ANDROID_HOME" \
  --env=ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" \
  org.godotengine.Godot \
  --headless \
  --path "$ROOT_DIR" \
  --export-debug "Android" "$APK"

if [[ ! -f "$APK" ]]; then
  echo "Build fallita: $APK non trovato" >&2
  exit 1
fi

ls -lh "$APK"
echo "APK pronto: $APK"
