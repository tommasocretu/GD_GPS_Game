# Rendering 3D della mappa OSM in Godot

Type: research
Status: resolved
Blocked by: —

## Question

Come trasformare dati OpenStreetMap in una scena 3D low-poly in Godot 4.7 mobile?

Confrontare almeno:

- Terreno raster da tile XYZ + edifici estrusi dai footprint OSM (Overpass API).
- Vector tile (MVT) con rendering custom o plugin.
- SDK/plugin esistenti (MapLibre, Cesium, ecc.) integrabili in Godot.

Valutare qualità visiva, complessità, performance su mobile, licenze, copertura dei dati e streaming. Output: architettura raccomandata per la slice, strumenti, rischi e fonti. Findings in `.scratch/gps-game/research/02-osm-3d.md`.

## Answer

Raccomandazione: **opzione A** per la slice — terreno raster XYZ (z17, 256 px, chunk 2×2 tile) + edifici estrusi dai footprint Overpass, una `ArrayMesh` per chunk con vertex color e un materiale, parsing/estrusione su worker thread, cache LRU (≥7 giorni tile, 7–30 giorni edifici).

Perché:
- massima qualità dei footprint vicino al giocatore (z17 ≈0.84 m/px; MVT max z14 ≈6.7 m/px);
- solo API Godot standard (`HTTPRequest`, `Image`, `Geometry2D`, `ArrayMesh`), niente decoder MVT;
- performance mobile controllabile: ~45 draw call per 3×3 chunk, ombre off, texture 256 px;
- licenze gestibili: OSM ODbL + provider tile (ticket 03), Overpass con cache e limiti.

MVT custom (OpenMapTiles/OpenFreeMap) resta il piano B per produzione/offline; Shortbread non ha altezze. SDK/plugin: MapLibre Native non è integrabile come scena 3D Godot su Android; `maplibre-native-godot` è desktop-only; 3D Tiles for Godot è desktop-only/Forward+; Cesium for Godot è deprecato.

Rischi principali: limiti/latenza Overpass (100 query/giorno per uso regolare), altezze OSM sparse (~28M `height` su ~713M `building`), texture runtime non compresse (budget RAM), mismatch raster/Overpass, threading.

Report completo: [`02-osm-3d.md`](../research/02-osm-3d.md) (misure, confronto, architettura, rischi, fonti).
