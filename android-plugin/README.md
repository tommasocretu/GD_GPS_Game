# GpsPlugin (Android v2)

Plugin interno minimale: `LocationManager` di piattaforma → segnale Godot `location_fix`.

- `FUSED_PROVIDER` su API 31+, fallback `GPS_PROVIDER` / `NETWORK_PROVIDER`;
- 1 Hz, min 500 ms, distanza minima 1 m, alta precisione;
- nessuna dipendenza da Google Play Services;
- permessi dichiarati nel manifest dell'AAR: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`;
- threading: il listener costruisce solo un `Dictionary` e chiama `emitSignal()`, che Godot
  rimanda sul render thread; nessuna chiamata GDScript dal thread Android.

## Build

```bash
./scripts/build_gps_plugin.sh
```

Lo script compila con `javac` contro `android.jar` e il `classes.jar` di Godot 4.7.2
(scaricato da Maven Central se manca), impacchetta `addons/gps.aar` e lo lascia al build
Gradle di Godot, che lo include automaticamente.

## Segnali

- `location_fix(Dictionary)`: `latitude`, `longitude`, `accuracy`, `altitude`, `speed`
  (−1 se assente), `bearing` (−1 se assente), `time_ms`, `elapsed_ns`, `age_ms`, `is_mock`.
- `location_error(String)`: `missing_permission`, `coarse_only`, `location_disabled`,
  `no_provider`, `start_failed`, `provider_disabled:<provider>`.

## Metodi

- `start_updates(interval_ms, min_interval_ms, min_distance_m) -> bool`
- `stop_updates()`
- `get_last_fix() -> Dictionary`
- `get_active_provider() -> String`
