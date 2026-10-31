# GD_GPS_Game

Prototipo di gioco GPS mobile in verticale, in stile Pokémon GO, con mappa OpenStreetMap 3D low-poly.

## Build Android

Requisiti: Godot 4.7.2 (flatpak), Android SDK con platform 36 e build-tools 36, JDK 17.

```bash
./scripts/build_android.sh
```

APK di debug: `build/android/gps-game-debug.apk` (arm64-v8a, minSdk 26, targetSdk 36).
