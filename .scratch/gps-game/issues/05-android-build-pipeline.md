# Pipeline di build Android e distribuzione APK

Type: task
Status: resolved
Blocked by: —

## Question

Mettere in piedi la pipeline minima per produrre un APK installabile su Fairphone Gen 6 (Android 16) e inviarlo via WhatsApp.

Include:

- Android SDK/command-line tools ed export template Godot 4.7.2;
- export preset Android, min SDK 26, target SDK 36;
- permessi `INTERNET` e `ACCESS_FINE_LOCATION`;
- firma debug/release e build da riga di comando;
- installazione manuale dell'APK sul dispositivo.

Fatto quando: un APK di prova si installa e si apre sul Fairphone. L'answer registra comandi, percorsi e dove vivono le credenziali (non i segreti).

## Comments

- 2026-10-31: pipeline configurata. Installato il build template Android in `android/`, preset Gradle con `minSdk 26`, `targetSdk 36`, `arm64-v8a`, permessi `INTERNET` + `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION`, ETC2/ASTC abilitato. Script: `scripts/build_android.sh`. APK: `build/android/gps-game-debug.apk` (77 MB, firmato con la debug keystore Godot, schema v2). Verifiche eseguite: `aapt2 dump badging` e `apksigner verify`.
- In attesa: installazione e apertura sul Fairphone Gen 6 (Android 16). Checklist: inviare l'APK via WhatsApp, aprirlo sul telefono, consentire l'installazione da app sconosciute, installare, aprire. Atteso: cubo verde e testo "GD GPS Game / Android build OK".
- 2026-10-31: installato e aperto sul Fairphone Gen 6 (Android 16). Funziona.

## Answer

Pipeline Android completata e validata sul Fairphone Gen 6 (Android 16): l'APK si installa, si apre e mostra il cubo verde con il testo "GD GPS Game / Android build OK".

- Build template Gradle in `android/`.
- Preset: `export_presets.cfg` — Gradle build, minSdk 26, targetSdk 36, arm64-v8a, permessi `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, ETC2/ASTC.
- Comando: `./scripts/build_android.sh` → `build/android/gps-game-debug.apk`.
- Firma: debug keystore Godot in `~/.var/app/org.godotengine.Godot/data/godot/keystores/debug.keystore` (password default `android`), schema v2. Release keystore non ancora configurata.
- Verifiche: `aapt2 dump badging`, `apksigner verify`, avvio headless della scena.
- APK testato: 77 MB, SHA-256 `df254fa8583c99c7bdb47b107f8b51ceb8e1475773340c05bceb56e61c17ec0b`.
