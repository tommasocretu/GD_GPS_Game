# Mappa: GPS Game — vertical slice 3D in stile Pokémon GO

## Destination

Una vertical slice Android in portrait, 3D low-poly in stile Pokémon GO: un avatar si muove su una mappa OpenStreetMap (terreno con tile + edifici estrusi vicino al giocatore) seguendo il GPS reale, con HUD di debug e simulatore di percorso. Niente POI, catture, inventario, backend, iOS o AR.

## Notes

- Repo: Godot 4.7.2 (flatpak), mobile renderer, Jolt Physics; progetto praticamente vuoto.
- Dispositivo di test: Fairphone Gen 6, Android 16. Distribuzione APK via WhatsApp (niente debug USB assunto).
- Preferenze: camera obliqua fissa north-up, portrait bloccato; stile low-poly; copertura dinamica ovunque con cache; avatar low-poly CC0 animato; min SDK 26; provider tile free-tier con API key; attribuzione OSM visibile.
- Lingua: documenti e ticket in italiano; codice e identificatori in inglese.
- Provider: MapTiler Cloud Free (solo non commerciale/R&D; per uso commerciale serve un piano a pagamento). API key in `secrets.cfg` ignorato, mai nel repo.
- Build Android: `./scripts/build_android.sh` → `build/android/gps-game-debug.apk`; debug keystore Godot, schema v2, validata sul Fairphone.
- Tracker: locale, `.scratch/gps-game/` (GitHub Issues non disponibile: `gh` non autenticato).
- Skill consigliate alle sessioni: `grilling`, `domain-modeling`, `research`, `prototype`.
- Questa mappa produce decisioni, non la slice: l'implementazione parte quando il percorso è chiaro.

## Decisions so far

- [GPS input in Godot 4.7 su Android](issues/01-gps-input-godot-android.md): plugin Android v2 interno su `LocationManager`, niente Play Services; 1 Hz, foreground, permessi runtime; background fuori scope.
- [Rendering 3D della mappa OSM in Godot](issues/02-osm-3d-rendering.md): terreno raster z17 + edifici estrusi da Overpass, una `ArrayMesh` per chunk, parsing su worker thread, cache LRU; MVT come piano B.
- [Provider tile OSM free-tier e attribuzione](issues/03-tile-provider.md): MapTiler Cloud Free, stile custom raster `@2x`, 100k richieste/mese, key in `secrets.cfg`, attribuzione OSM + logo.
- [Coordinate GPS, proiezione e scala del mondo](issues/04-coordinate-system-world-scale.md): piano tangente locale ellissoidico (1 unità = 1 m), Mercator solo per le tile, floating origin ogni 2 km, lat/lon in float64.
- [Pipeline di build Android e distribuzione APK](issues/05-android-build-pipeline.md): Gradle build con minSdk 26/targetSdk 36, script `scripts/build_android.sh`, APK debug firmata e validata sul Fairphone Gen 6.
- [Avatar low-poly CC0 con animazioni](issues/06-avatar-asset.md): Quaternius Ultimate Modular Men `Casual_Male`, CC0, glTF 1,858 m con Idle/Walk/Run.

## Not yet specified

- Field test end-to-end della slice su Fairphone Gen 6: protocollo operativo, percorso, raccolta log.
- Gestione dei casi degradati: permesso GPS negato/revocato, segnale assente, mock location, GPS impreciso in centro città.
- Comportamento con dati OSM incompleti: edifici mancanti, footprint fuori scala, strade non allineate.
- Performance e memoria in zone dense di edifici; budget di draw call, texture e mesh.
- Fallback di sviluppo desktop con fake GPS e registrazione/riproduzione di percorsi.
- Dettagli di HUD/UI: cosa mostrare, layout portrait, safe area.
- Privacy della posizione: dati solo on-device, nessun backend.
- Aggiornamenti dell'app e firma delle APK distribuite via WhatsApp.
- Eventuale passaggio da raster a vector tile se la qualità non basta.
- Test di performance su Fairphone Gen 6: FPS, memoria texture, batteria.
- Comportamento oltre la zona ancorata: rebase, ricostruzione geometria, continuità visiva.

## Out of scope

- POI, catture, inventario, combattimento, quest e progressione.
- Backend, account, multiplayer, sincronizzazione e analytics.
- iOS e piattaforme desktop come target di gioco.
- AR/ARCore e fotocamera.
- Character creator e personalizzazione estetica.
- Grafica realistica e città ad alta fedeltà.
- Mappe offline complete e navigazione turn-by-turn.
- Monetizzazione e funzionalità social.
- Tracciamento GPS in background/schermo spento (foreground service Android 14+).
- Distribuzione commerciale e passaggio a un piano MapTiler a pagamento.
