# Prototipo di movimento GPS

Type: prototype
Status: in progress
Blocked by: 07, 08, 14

## Question

Costruire un prototipo con GPS reale (o fake GPS su desktop) che muove l'avatar su un piano semplice con la camera definitiva, per validare smoothing, animazioni e HUD. Test su Fairphone. Output: build/scena + note.

## Implementation notes

**Implementato il prototipo desktop e la build Android; manca il test sul Fairphone.**

- Scena: `scenes/Main.tscn` (piano con griglia, avatar, camera rig, HUD, landmark di prova).
- Modello: `scripts/movement/movement_model.gd` + `movement_config.gd` (ticket 07).
- Camera: `scripts/camera/camera_rig.gd` + `camera_config.gd` (ticket 08).
- GPS Android: plugin v2 interno in `android-plugin/gps/`, AAR in `addons/gps.aar`, wrapper `scripts/gps/android_gps_source.gd`.
- Fake GPS desktop: `scripts/gps/fake_gps_source.gd` (WASD, Shift = run, `--auto-walk` per demo).
- HUD: `scripts/ui/debug_hud.gd` (safe area, stato, fix, slider debug F2, marker F3, toast snap, overlay INIT/DENIED, attribuzione).
- Test headless: `tests/run_tests.gd` (45 check, 0 failure) e `tests/camera_composition.gd` (65,3% / 8,8% / 50%).
- Build: `./scripts/build_android.sh` → `build/android/gps-game-debug.apk`; plugin e meta-data verificati dentro l'APK.

**Da fare sul dispositivo:** installare l'APK sul Fairphone Gen 6, concedere la posizione precisa, verificare fix a 1 Hz, idle/walk, snap, STALE/LOST, comportamento dietro gli edifici e FPS. Il protocollo completo resta nel ticket 12.

**Nota composizione:** l'offset camera è stato scalato da `(0, 13, 18.5)` a `(0, 11.375, 16.1875)` (×0.875) perché con pitch −27° e FOV 50° l'avatar proiettato è ~8,8% e resta al 65% dello schermo; con l'offset originale era ~7,6%, fuori dal criterio 8,5–9,5% del ticket 08.
