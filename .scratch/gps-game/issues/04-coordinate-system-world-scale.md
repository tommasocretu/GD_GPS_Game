# Coordinate GPS, proiezione e scala del mondo

Type: research
Status: resolved
Blocked by: —

## Question

Come mappare lat/lon GPS in coordinate di mondo 3D stabili per un'area che il giocatore percorre a piedi?

Definire:

- proiezione locale (ENU/tangent plane vs Web Mercator);
- scala 1 unità = 1 metro;
- allineamento tra tile raster ed edifici;
- floating origin/rebasing;
- precisione a distanze urbane e passaggio a nuove zone.

Output: formule/algortimi, pseudocodice GDScript, errori attesi e fonti. Findings in `.scratch/gps-game/research/04-coordinates.md`.

## Answer

**Decisione:** il mondo 3D usa un **piano tangente locale ellissoidico**, non Web Mercator. Web Mercator (EPSG:3857) resta solo il CRS delle tile. La posizione globale si conserva come lat/lon WGS84 in `float` a 64-bit; mai in `Vector2`/`Vector3`, che sono a 32-bit.

- **Formule:** con anchor `(φ0, λ0)`, `E = N0 cosφ0 (λ−λ0)`, `N = M0 (φ−φ0)`; in Godot `Vector3(E, h, −N)`. `M0`/`N0` sono i raggi di curvatura WGS84 all'anchor. Inversa banale: `λ = λ0 + E/(N0 cosφ0)`, `φ = φ0 + N/M0`.
- **Scala 1:1:** 1 unità = 1 m all'anchor. Lungo il meridiano l'errore del piano tangente è 3 mm a 2 km, 4,9 cm a 8 km; nel caso peggiore a distanza `d` è ~0,31 m a 2 km, ~1,25 m a 4 km, ~5 m a 8 km. Il float32 locale è 0,24 mm a 2 km. Il GPS (3–5 m cielo aperto, 10–30 m città) domina fino a ~4 km: non serve la build double precision di Godot; tenere il raggio di zona ≤4 km.
- **Tile:** gli angoli `(z,x,y)` si convertono in lat/lon con le formule slippy e poi nello stesso piano tangente degli edifici. La tile è un rettangolo `W × H` con `W = N0 cosφ0 Δλ`, `H = M0 Δφ`; non è quadrata (`W/H ≈ 1,0034` a 45°). Le tile 512 px “retina” (se il provider usa lo stesso schema) coprono la stessa estensione delle 256 px: non vanno scalate 2×. Attenzione a TMS (Y invertita) e al clamp ±85,05°.
- **Floating origin:** rebase traslazionale ogni 2 km, spostando i figli di `WorldRoot` e chiamando `reset_physics_interpolation()`; l'anchor della proiezione resta fisso. Nuovo anchor a ~4 km o cambio città, ricostruendo la geometria da lat/lon. Le entità persistenti salvano lat/lon, mai coordinate mondo.
- **Errori da evitare:** usare Mercator grezzo come metri (30–45% di errore in Italia); scalarlo solo per `cosφ` (3,7 m a 2 km); memorizzare coordinate globali in `Vector2`/`Vector3` (passo 0,5 m a `y≈5·10^6`); confondere 256/512 px; non convertire TMS.

Report completo con derivate, pseudocodice GDScript, tabella errori e fonti primarie: [`.scratch/gps-game/research/04-coordinates.md`](../research/04-coordinates.md).
