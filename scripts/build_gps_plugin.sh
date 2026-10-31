#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/gps-plugin"
OUT_AAR="$ROOT_DIR/addons/gps.aar"

JDK="${JAVA_HOME:-$HOME/.local/opt/temurin-17}"
if [[ ! -x "$JDK/bin/javac" ]]; then
  JDK="$HOME/Documenti/android-studio/jbr"
fi
if [[ ! -x "$JDK/bin/javac" ]]; then
  echo "JDK 17 non trovato. Imposta JAVA_HOME." >&2
  exit 1
fi

ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
ANDROID_JAR="$ANDROID_SDK/platforms/android-36/android.jar"
if [[ ! -f "$ANDROID_JAR" ]]; then
  echo "android.jar non trovato in $ANDROID_JAR" >&2
  exit 1
fi

GODOT_AAR="$ROOT_DIR/android/build/libs/debug/godot-lib.template_debug.aar"
if [[ ! -f "$GODOT_AAR" ]]; then
  GODOT_AAR="$ROOT_DIR/build/godot-lib-4.7.2.stable.aar"
  if [[ ! -f "$GODOT_AAR" ]]; then
    echo "Scarico godot-lib 4.7.2.stable da Maven Central..."
    curl -L --fail --max-time 300 \
      -o "$GODOT_AAR" \
      "https://repo1.maven.org/maven2/org/godotengine/godot/4.7.2.stable/godot-4.7.2.stable.aar"
  fi
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes" "$BUILD_DIR/aar" "$BUILD_DIR/godot"
unzip -q -o "$GODOT_AAR" classes.jar -d "$BUILD_DIR/godot"

find "$ROOT_DIR/android-plugin/gps/src/main/java" -name '*.java' > "$BUILD_DIR/sources.txt"
"$JDK/bin/javac" \
  -source 17 -target 17 \
  -classpath "$ANDROID_JAR:$BUILD_DIR/godot/classes.jar" \
  -d "$BUILD_DIR/classes" \
  @"$BUILD_DIR/sources.txt"

"$JDK/bin/jar" cf "$BUILD_DIR/aar/classes.jar" -C "$BUILD_DIR/classes" .
cp "$ROOT_DIR/android-plugin/gps/src/main/AndroidManifest.xml" "$BUILD_DIR/aar/AndroidManifest.xml"

mkdir -p "$(dirname "$OUT_AAR")"
rm -f "$OUT_AAR"
(
  cd "$BUILD_DIR/aar"
  zip -q -r "$OUT_AAR" AndroidManifest.xml classes.jar
)

echo "AAR pronto: $OUT_AAR"
unzip -l "$OUT_AAR"
