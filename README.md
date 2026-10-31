# GD_GPS_Game

Prototipo di gioco GPS mobile in verticale, in stile Pokémon GO, con mappa OpenStreetMap 3D low-poly.

Stato attuale: **prototipo di movimento GPS** (ticket 11) — avatar Quaternius, modello di
smoothing GPS, camera north-up fissa, HUD di debug, plugin Android `GpsPlugin` e fake GPS
desktop. Il rendering della mappa OSM arriverà dopo la configurazione MapTiler (ticket 13).

## Build Android

Requisiti: Godot 4.7.2 (flatpak), Android SDK con platform 36 e build-tools 36, JDK 17.

```bash
./scripts/build_gps_plugin.sh   # solo dopo modifiche a android-plugin/
./scripts/build_android.sh
```

APK di debug: `build/android/gps-game-debug.apk` (arm64-v8a, minSdk 26, targetSdk 36).

Il plugin GPS è un AAR in `addons/gps.aar`, incluso automaticamente dal Gradle build di
Godot 4.7. Il manifest dell'AAR aggiunge `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION`
e il meta-data `org.godotengine.plugin.v2.GpsPlugin`.

Per la futura integrazione MapTiler: copia `secrets.example.cfg` in `secrets.cfg`
(ignorato) e inserisci la API key; la configurazione del provider arriverà con il ticket 13.

## Desktop

```bash
flatpak run org.godotengine.Godot --path .
```

Senza il plugin Android parte il fake GPS:

- `WASD`: cammina a 1,4 m/s;
- `Shift` + `WASD`: corri a 5 m/s;
- `F2`: pannello slider debug (`smooth_time`, soglia di lock, `max_speed`);
- `F3`: marker magenta del fix GPS grezzo.

Per una camminata automatica (screenshot/demo):

```bash
flatpak run org.godotengine.Godot --path . -- --auto-walk
```

## Test

Test headless deterministici del piano tangente e del modello di movimento:

```bash
flatpak run org.godotengine.Godot --headless --path . --script res://tests/run_tests.gd
flatpak run org.godotengine.Godot --headless --path . --script res://tests/camera_composition.gd
```

Il primo copre: proiezione e tile OSM, anchor a ≤20 m, lock da fermo, rettilineo,
salti da 10 m e 40 m, STALE/LOST, accuratezza debole, conferma outlier, heading e rebase.
Il secondo verifica l'inquadratura: avatar al 65% ±2%, altezza proiettata 8,5–9,5%,
centrato orizzontalmente.
