# 04 — Coordinate GPS, proiezione e scala del mondo

- Ticket: [04-coordinate-system-world-scale](../issues/04-coordinate-system-world-scale.md)
- Tipo: research
- Data: 2026-10-31
- Scope: vertical slice Android (Godot 4.7.2, renderer mobile, Jolt), mondo 3D a piedi, tile raster OSM + edifici estrusi.
- Fonti primarie numerate in fondo; i claim principali hanno il riferimento `[S#]`.

---

## 1. Decisione in breve

| Aspetto | Decisione |
|---|---|
| CRS globale | WGS84 lat/lon in `float` (64-bit) + EPSG:3857 **solo** per indicizzare e scaricare le tile |
| Frame del mondo 3D | piano tangente ellissoidico ancorato a `(φ0, λ0)`, in metri veri |
| Assi Godot | `+X` = est, `+Y` = su, `−Z` = nord (`Vector3.FORWARD` è nord) `[S13]` |
| Scala | 1 unità = 1 metro all'anchor; errore di proiezione ~0,3 m a 2 km e ~1,3 m a 4 km nel caso peggiore (lungo il meridiano ~3 mm a 2 km) |
| Floating origin | rebase traslazionale ogni 2 km; l'anchor della proiezione resta fisso |
| Nuove zone | nuovo anchor quando il giocatore supera ~4 km o cambia città; geometria ricostruita da lat/lon |
| Precisione | il GPS (3–5 m in cielo aperto, 10–30 m in città) domina fino a ~4 km; a 8 km la proiezione è comparabile |
| Build double precision | **no**; Godot documenta l'origine shifting come alternativa mobile `[S12]` |

**Regola operativa:** tutto entra come lat/lon WGS84; si converte nel piano tangente locale. Web Mercator non è mai usato come unità di mondo. Le tile sono solo texture georeferenziate: i loro angoli vengono convertiti con la stessa funzione degli edifici.

```
GPS (lat, lon, alt) ─┐
OSM way (lat, lon) ──┼─► GeoFrame.to_world() ─► Vector3(E, U, −N) − origin ─► Godot
Tile (z, x, y) ─► bounds lat/lon ─┘
```

---

## 2. Requisiti e ipotesi

- Il giocatore cammina a 0,5–2 m/s; l'area di gioco della slice è dell'ordine di 1–4 km.
- La camera è obliqua, north-up, con un raggio visibile verosimile di 300–800 m.
- Il terreno della slice è un piano a `y = 0`; gli edifici sono volumi estrusi dai footprint OSM.
- Il dispositivo di test è un Fairphone Gen 6 (Android 16, ARM64). Il target è mobile, non desktop.
- Le tile arrivano da un provider XYZ; la scelta del provider è del ticket 03. Qui si assume EPSG:3857/XYZ, il caso normale per OSM `[S1][S2]`.
- Gli edifici arrivano da Overpass con geometria lat/lon (`out geom`) `[S11]`.

---

## 3. Sistemi di coordinate

### 3.1 WGS84 geodetico (lat/lon)

GPS Android e dati OSM usano WGS84: latitudine `φ`, longitudine `λ` in gradi, altezza ellissoidica `h` in metri `[S8]`. L'ellissoide WGS84 ha:

```
a  = 6378137.0 m                 (semiasse maggiore)
f  = 1 / 298.257223563           (schiacciamento)
e² = 2f − f² = 0.0066943799901413165
```

I due raggi di curvatura che servono sono quello meridiano `M(φ)` e quello del primo verticale `N(φ)`:

```
M(φ) = a (1 − e²) / (1 − e² sin²φ)^(3/2)
N(φ) = a / (1 − e² sin²φ)^(1/2)
```

`M` è il raggio di curvatura nella direzione nord-sud; `N` in direzione est-ovest (il raggio del parallelo è `N cosφ`). Le stesse formule compaiono nella definizione EPSG del metodo 1024 come `ρ` e `ν` `[S3]`; i parametri WGS84 sono nel WKT di EPSG:3857 `[S2]`.

Precisione delle coordinate: 7 decimali di grado valgono ~1,1 cm in latitudine e ~0,8 cm in longitudine a 45° `[S6]`. Il GPS reale è molto meno preciso; non serve più di 7 decimali.

### 3.2 Web Mercator EPSG:3857

EPSG:3857 è la proiezione delle tile XYZ. Usa formule sferiche con `R = a = 6378137 m` applicate a lat/lon ellissoidici `[S2][S3]`:

```
x = R λ
y = R ln tan(π/4 + φ/2) = R asinh(tan φ)
```

con `λ`, `φ` in radianti. L'inversa è:

```
λ = x / R
φ = atan(sinh(y / R))
```

La latitudine è valida fino a `±85.05112878°` (`atan(sinh(π))`), dove `|y| = πR = 20037508.342789244 m`. In Italia il limite non è un problema, ma va clampato per evitare `inf`/`NaN`.

**Web Mercator non è conforme sull'ellissoide.** EPSG lo dice esplicitamente: applica formule sferiche a coordinate ellissoidali e il fattore di scala varia con l'azimut `[S3]`. I fattori di scala nelle due direzioni principali sono:

```
h = R / (M(φ) cosφ)     (scala lungo il meridiano, nord-sud)
k = R / (N(φ) cosφ)     (scala lungo il parallelo, est-ovest)
```

Un delta di Mercator si riporta al suolo **dividendo**: `ΔE = Δx/k`, `ΔN = Δy/h` (con `h`, `k` valutati alla latitudine giusta). Moltiplicare per `cosφ` è solo un'approssimazione; l'Appendice A lo deriva. Nota: qui `h`/`k` sono i fattori di scala EPSG, non l'altezza ellissoidica `h` di §3.1; nel codice usare nomi distinti (`scale_n`, `scale_e`, `alt`).

A latitudini italiane `h` e `k` sono entrambi ~1,3–1,45 e differiscono di ~0,3–0,4%:

| φ | h | k | h/k | distorsione angolare ω = 2 asin(\|h−k\|/(h+k)) |
|---:|---:|---:|---:|---:|
| 41° | 1.328182 | 1.323103 | 1.003839 | 0.2195° |
| 45° | 1.416602 | 1.411845 | 1.003370 | 0.1928° |
| 46° | 1.441735 | 1.437061 | 1.003252 | 0.1860° |

Conseguenze pratiche:

1. **Mercator grezzo come unità di mondo è sbagliato di ~30–45% in Italia.** A 45° un edificio largo 10 m risulterebbe largo 14,14 m; a 41° 13,25 m; a 46° 14,39 m. La scala non è 1:1.
2. **Anche scalare Mercator per `cosφ0` non basta.** Toglie il grosso del fattore `secφ`, ma lascia un bias di ~0,17% e un'anisotropia di ~0,34%: a 2 km sono ~3,7 m in nord e ~3,35 m in est rispetto al suolo vero (tabella §3.5). È paragonabile al GPS, quindi per un prototipo può bastare, ma non è “1 unità = 1 metro”.
3. **EPSG:3857 va usato solo per la griglia delle tile**, non come sistema di riferimento metrico del mondo. La definizione EPSG stessa avverte che non è un sistema geodetico riconosciuto e che rispetto a EPSG:3395 dà errori di scala fino allo 0,7% e differenze di northing fino a 43 km sulla mappa (21 km al suolo) `[S2]`.

### 3.3 Piano tangente locale (scelta raccomandata)

Si sceglie un anchor geodetico `(φ0, λ0)` e si definiscono coordinate locali in metri:

```
E = N0 cosφ0 (λ − λ0)
N = M0 (φ − φ0)
U = h − h0
```

dove `M0 = M(φ0)`, `N0 = N(φ0)`, e `λ−λ0` è normalizzata in `[−π, π]` (antimeridiano). Nota di notazione: `N` senza pedice è la **coordinata nord**; `N0` è il raggio di curvatura del primo verticale all'anchor. `E` è la coordinata est, `U` l'altezza sul piano tangente. Questa è l'espansione al primo ordine della proiezione ENU esatta (ECEF → East/North/Up), con i raggi di curvatura valutati all'anchor. È il classico “local tangent plane” `[S17][S18]`.

In Godot:

```
world = Vector3(E, U, −N)
```

perché `+X` è est, `+Y` è su e `−Z` è nord `[S13]`. L'inversa, sufficiente per debug e conversione di punti, è:

```
λ = λ0 + E / (N0 cosφ0)
φ = φ0 + N / M0
```

**Perché è la scelta giusta per questa slice:**

- È metrico per costruzione: `E`, `N`, `U` sono metri sul piano tangente; non c'è `secφ`.
- È separabile: `E` dipende solo da `λ`, `N` solo da `φ`. Una tile lat/lon diventa un rettangolo **allineato agli assi** nel mondo; il reticolo delle tile resta un reticolo rettangolare, con righe di altezza leggermente variabile e colonne di larghezza costante. Questo semplifica chunk, culling e streaming.
- L'errore rispetto all'ENU ellissoidico esatto è `O(d²/R)`. **Lungo il meridiano** è minuscolo (3,1 mm a 2 km, 1,2 cm a 4 km, 4,9 cm a 8 km), ma il **caso peggiore a distanza radiale `d`** è ~`d²/(2R)`: **0,31 m a 2 km**, 1,25 m a 4 km, 5,0 m a 8 km, 20 m a 16 km. A 2 km è ~10× sotto il GPS; a 4 km è ancora sotto; a 8 km è comparabile. Per questo il raggio di zona va tenuto ≤4 km.
- L'errore verticale è la curvatura terrestre: il suolo vero scende sotto il piano tangente di `d²/(2R)` (0,31 m a 2 km, 5,0 m a 8 km). La slice è piatta e il raggio visibile è < 1 km, quindi l'errore visibile è < 8 cm. Se in futuro servirà terreno collinare, si aggiunge un DEM locale, non si cambia proiezione.
- L'inversa è chiusa e banale; non serve ECEF a runtime.

### 3.4 Perché non ENU “esatto” a runtime

L'ENU esatto via ECEF è:

```
X = (N + h) cosφ cosλ
Y = (N + h) cosφ sinλ
Z = (N(1 − e²) + h) sinφ

ΔX = X − X0, ecc.

E = −sinλ0 ΔX + cosλ0 ΔY
N = −sinφ0 cosλ0 ΔX − sinφ0 sinλ0 ΔY + cosφ0 ΔZ
U =  cosφ0 cosλ0 ΔX + cosφ0 sinλ0 ΔY + sinφ0 ΔZ
```

`[S17][S18]`. È la formula di riferimento per i test, ma a runtime è più codice e più costosa; il piano tangente lineare è accurato entro ~0,3 m a 2 km e ~1,3 m a 4 km nel caso peggiore. L'errore residuo è la curvatura terrestre (in particolare la curvatura dei paralleli), che la slice piatta ignora comunque.

### 3.5 Confronto quantitativo

A 45° di latitudine, errore rispetto al suolo ellissoidico vero. “Mercator × `cosφ0`” significa il passaggio naïf `E = (x − x0)·cosφ0`, `N = (y − y0)·cosφ0`:

| Metodo | 1 km | 2 km | 8 km |
|---|---:|---:|---:|
| Mercator grezzo come metri | ~414 m (41,4%) | ~828 m | ~3,31 km |
| Mercator × `cosφ0` | ~1,7 m | ~3,7 m (N) / 3,35 m (E) | ~18,5 m (N) / 13,4 m (E) |
| Piano tangente, lungo il meridiano | 0,0008 m | 0,0031 m | 0,0485 m |
| Piano tangente, caso peggiore a distanza `d` | ~0,08 m | ~0,31 m | ~5,0 m |

Per un punto a coordinate locali `(E, N)`, l'errore dominante della linearizzazione è:

```
ΔE ≈  E·N·tanφ / R
ΔN ≈ −E² / (2R)
ΔU ≈ −(E² + N²) / (2R)
```

Quindi il caso peggiore a distanza radiale `d` è ~`d²/(2R)` nella componente E (la N è circa metà); lungo il meridiano (`E = 0`) resta solo la variazione di `M`, dell'ordine dei millimetri. Queste formule spiegano perché la tabella “lungo il meridiano” è molto migliore del caso peggiore.

Dettaglio del piano tangente e del float32:

| Distanza radiale `d` | Errore lungo il meridiano (componente N) | Errore max orizzontale ~`d²/(2R)` (componente E) | Passo float32 (`2^(floor(log2 d)−23)`) |
|---:|---:|---:|---:|
| 1 km | 0,8 mm | 0,078 m | 0,000061 m |
| 2 km | 3,1 mm | 0,314 m | 0,000244 m |
| 4 km | 12,4 mm | 1,256 m | 0,000488 m |
| 8 km | 48,5 mm | 5,026 m | 0,000977 m |
| 16 km | 0,186 m | 20,10 m | 0,001953 m |
| 32 km | 0,675 m | 80,41 m | 0,003906 m |
| 64 km | 2,16 m | 321,7 m | 0,007813 m |

L'errore "lungo il meridiano" è la componente N per un punto a nord; il caso peggiore è ~`d²/(2R)` nella componente E (la N è circa metà), e l'abbassamento verticale `U` è dello stesso ordine. Il passo float32 è lo spacing nel binario dell'esponente. A 2 km il GPS (3–5 m) è ~10 volte l'errore peggiore; a 4 km è ~3 volte; a 8 km è comparabile. **Fino a ~4 km la proiezione non è il problema; oltre, sì.**

---

## 4. Scala: 1 unità = 1 metro

- Godot usa metri come unità di scena per convenzione; glTF dichiara esplicitamente che “the units for all linear distances are meters” `[S19]`. Un avatar alto 1,7 m, un piano di 3 m per piano e una tile z18 di ~108 m sono coerenti se l'import non applica scale. La scala è 1:1 all'anchor; l'errore di proiezione cresce con `d²/R` (tabella §3.5) e a 4 km è ~1,25 m, ancora sotto il GPS.
- I modelli glTF/GLB importati in Godot devono avere scala 1.0. Se un asset è stato esportato in centimetri, va scalato 0,01 all'import o nel nodo radice. Il ticket 06 sceglie l'avatar; qui basta fissare la convenzione.
- Le altezze OSM sono in metri: `height` è l'altezza massima dell'edificio dal punto più basso a terra, `building:levels` è il numero di piani fuori terra; `min_height` è l'altezza sotto la struttura `[S9][S10]`. Fallback ragionevole per la slice: `height` se presente, altrimenti `building:levels × 3.0 m`, altrimenti 6 m.
- Verticale: la slice usa `y = 0` come terreno. L'altitudine GPS Android è “meters above the WGS84 reference ellipsoid” `[S8]`, non ortometrica: non usarla come quota del terreno, perché oscilla di decine di metri e non coincide con `ele` OSM. Per la slice piatta, `y = 0` e gli edifici partono da 0.
- Non confondere la risoluzione della texture con la dimensione del mondo: per i provider che offrono 512 px come variante “retina” della stessa tile, l'estensione geografica è la **stessa** di una 256×256 allo stesso zoom; cambia solo la densità di pixel `[S1]`. Se si scala il mondo in base ai pixel, si ottiene un errore di 2×. Verificare comunque lo schema del provider (ticket 03): alcuni usano 512 px con una numerazione di zoom diversa.

---

## 5. Allineamento tile raster ↔ edifici

### 5.1 Geometria della tile XYZ

Per una tile `(z, x, y)`, con `n = 2^z`:

```
lon_w = x / n · 360 − 180
lon_e = (x + 1) / n · 360 − 180

lat_n = atan(sinh(π (1 − 2y/n)))        [radianti, poi in gradi]
lat_s = atan(sinh(π (1 − 2(y+1)/n)))    [radianti, poi in gradi]
```

`[S1]`. La tile è l'insieme `[lon_w, lon_e] × [lat_s, lat_n]`; l'angolo nord-ovest è `(lat_n, lon_w)`, il sud-est `(lat_s, lon_e)`. Un pixel `(px, py)` ha centro `(px + 0.5, py + 0.5)`; i bounds della tile usano gli angoli interi. La risoluzione al suolo per pixel, per tile da 256 px, è `156543.033928 · cosφ / 2^z` m/px `[S4]`.

Nel piano tangente ogni tile diventa un rettangolo allineato agli assi:

```
W = N0 cosφ0 · (λ_e − λ_w)      [metri]
H = M0 · (φ_n − φ_s)            [metri]

E_c = N0 cosφ0 · ((λ_w + λ_e)/2 − λ0)
N_c = M0 · ((φ_n + φ_s)/2 − φ0)
```

e il nodo della tile va in `Vector3(E_c − origin_e, 0, −(N_c − origin_n))` con mesh di dimensioni `W × H`.

Esempi numerici (calcolati con le formule qui sopra):

| Posizione | z | W | H | Nota |
|---|---:|---:|---:|---|
| 41°N, 12°E | 18 | 115,542 m | 115,100 m | Italia centrale |
| 45°N, 12°E | 18 | 108,280 m | 107,916 m | Pianura padana |
| 45°N, 12°E | 19 | 54,140 m | 53,958 m | |
| 35,659°N, 139,701°E | 18 | 124,352 m | 123,801 m | Hachiko, Tokyo |

Le tile non sono quadrati perfetti nel mondo: `W/H = h0/k0 ≈ 1,0034` a 45°. È corretto così: la texture è stata resa in Mercator, che è anisotropa rispetto all'ellissoide; il rettangolo `W × H` è l'impronta al suolo vera. Se si forza `W = H`, il raster e gli edifici si disallineano di ~0,3% della distanza dal centro della tile: su una tile da 108 m la differenza `W − H` è ~0,36 m, cioè ~0,18 m per bordo, e i bordi delle tile adiacenti non combaciano.

Valutare `M0`/`N0` all'anchor (invece che per ogni tile) mantiene il reticolo esattamente rettilineo; la differenza rispetto a valutarli alla latitudine della tile è ~cm a 4 km, sotto il GPS. È un compromesso deliberato: precisione assoluta leggermente minore, ma nessun gap tra tile.

### 5.2 Mesh della tile

- Costruire un quad con i quattro angoli calcolati **dalla stessa funzione** usata per gli edifici. Gli angoli condivisi tra tile adiacenti devono essere calcolati una volta sola o comunque con gli stessi input, così non ci sono gap.
- UV: `(0,0)` a NW, `(1,0)` a NE, `(1,1)` a SE, `(0,1)` a SW. La `v` cresce verso sud, come nelle immagini XYZ.
- TMS: se il provider numera le Y da sud (TMS), convertire prima `y_xyz = n − 1 − y_tms`; altrimenti la mappa è specchiata nord-sud `[S5]`.
- Winding: non fidarsi della sola normale; fare un test visivo con la tile vista dall'alto. Se la tile è invisibile, invertire l'ordine degli indici. Per il terreno conviene comunque usare `cull_mode = disabled`: è un piano visto sempre dall'alto e si elimina ogni ambiguità di winding.
- Materiale: `StandardMaterial3D` con `albedo_texture`, `shading_mode = unshaded` per il terreno, `texture_filter = linear_with_mipmaps`, `texture_repeat = disabled`. Il clamp evita il bleeding dai bordi; niente `repeat`, altrimenti le tile si “incollano” male.
- Niente facce inferiori per gli edifici e base delle pareti a `y = 0.01` m (o polygon offset) per evitare z-fighting con il terreno a `y = 0`.
- Se si combinano più tile in una mesh di chunk, tenere i vertici relativi al centro del chunk (float32 piccolo) e mettere il nodo del chunk alla posizione mondiale. Questo riduce la perdita di precisione e le draw call.

### 5.3 Edifici

- Overpass `out geom` restituisce per ogni way una lista di `{lat, lon}` `[S11]`. Convertire ogni vertice con la stessa `latlon → tangent` usata per le tile.
- Triangolare il footprint in 2D (XZ) con ear clipping (`Geometry2D.triangulate_polygon`) o, per footprint convessi, con un fan. Attenzione al winding del poligono OSM: può essere orario o antiorario; la triangolazione deve gestire entrambi.
- Estrudere le pareti da `y = 0` a `y = height`; la copertura piatta a `y = height`. Per la low-poly, tetti piatti vanno bene; `roof:shape` è fuori scope.
- `height` e `min_height` sono in metri `[S9][S10]`. Il parser deve accettare `4`, `4 m`, `13'6"` e scartare valori non numerici; se `height` manca, usare `building:levels × 3.0` o un default. Se c'è `building:part`, la slice può ignorarlo e usare l'outline con l'altezza dell'outline; se si vuole più fedeltà, estrudere ogni parte con la sua altezza.
- Origine della mesh dell'edificio: centroide o centro del bounding box del footprint (il centroide può cadere fuori da un footprint concavo). Il nodo `MeshInstance3D` va a quel punto in coordinate mondo; i vertici restano piccoli. Questo è importante per la precisione e per il culling.
- Assegnazione al chunk: per centroidi; un edificio che sfora il bordo del chunk resta intero, non viene tagliato (per la slice va bene; se serve, clippare in seguito).

### 5.4 Errori di allineamento e loro causa

| Causa | Effetto | Ordine di grandezza |
|---|---|---|
| Edifici proiettati con ENU, tile con Mercator | offset crescente con la distanza | fino a ~0,3% della distanza (3 m a 1 km) |
| Tile forzate quadrate invece di `W × H` | raster e edifici disallineati ai bordi | ~0,18 m per bordo (`W−H` ≈ 0,36 m) su z18 a 45° |
| Tile 512 px trattata come 2× estensione | mondo 2× | grossolano |
| TMS vs XYZ non convertito `[S5]` | mappa specchiata nord-sud | grossolano |
| `lat`/`lon` invertiti | punto nel mare | grossolano |
| Gradi usati come radianti | coordinate ovunque | grossolano |
| Centro pixel vs angolo pixel | offset di mezzo pixel | ~0,2–0,3 m a z18 |
| Generalizzazione del raster | edifici non disegnati/strade spostate | 1–2 px |
| Offset di imagery satellite | edifici spostati rispetto alla foto | metri |
| Dati OSM vecchi/non allineati | footprint spostati | metri |

Il punto importante: **raster e edifici devono usare la stessa proiezione**. Se il raster è OSM Carto (renderizzato dagli stessi dati OSM) l'allineamento è buono; se è satellite, l'immagine può essere georeferenziata con offset di metri e non è un buon riferimento per validare la proiezione. Per la slice, meglio tile OSM vettoriali/stilizzate che satellite.

L'errore assoluto del piano tangente (§3.5) **non è un disallineamento raster/edifici**: entrambi usano la stessa trasformazione, quindi l'allineamento relativo è limitato dalla risoluzione del raster e dai dati, non dal valore assoluto `d²/R`. Il valore ~1,25 m a 4 km è l'errore assoluto rispetto al suolo vero, non lo scostamento locale tra una texture e un edificio vicino; la distorsione differenziale su una vista di 500 m a 4 km è ~0,3 m, confrontabile con la risoluzione del raster.

---

## 6. Floating origin e rebasing

### 6.1 Precisione in Godot

Godot usa `Vector2`, `Vector3`, `Vector4` a **32-bit** per default; `float` di GDScript è a **64-bit** `[S13]`. Anche `Node3D.global_position`/`position` sono `Vector3`, quindi 32-bit `[S15]`. La documentazione “Large world coordinates” spiega che la precisione peggiora allontanandosi dall'origine, che il float32 rappresenta esattamente gli interi fino a ±16.777.216 e che un'area giocabile a piedi fino a **8192×8192 m** centrata sull'origine è accettabile anche in prima persona `[S12]`. La proposta Godot #892 quantifica il problema: jitter percepibile a pochi km dall'origine e target di ~0,5 mm per un first-person `[S16]`. Per aree più grandi consiglia l'**origin shifting** su piattaforme mobile, perché la build `precision=double` richiede ricompilare editor ed export template, ha costo di performance/memoria ed è pensata per desktop `[S12]`.

Passo del float32:

| Distanza | Passo |
|---:|---:|
| 512 m | 0,061 mm |
| 1 km | 0,122 mm |
| 2 km | 0,244 mm |
| 4 km | 0,488 mm |
| 8 km | 0,977 mm |
| 16 km | 1,95 mm |
| 64 km | 7,81 mm |
| 1.000 km | 6,25 cm |

A 2 km il passo è 0,24 mm: oltre 10.000 volte più fine del GPS. A 8 km è 1 mm, ancora oltre 3.000 volte più fine. **Per una slice di 1–2 km il rebasing non è strettamente necessario**; è però economico e va messo ora per evitare sorprese quando l'area cresce o il giocatore cammina a lungo.

### 6.2 Due concetti separati

- **Projection anchor** `(φ0, λ0)`: definisce `M0`, `N0`, `cosφ0`. Cambiarlo cambia la proiezione: la geometria va ricostruita o trasformata.
- **Render origin** `(origin_e, origin_n)`: è solo una traslazione nel frame. Cambiarlo è un rebase puro, invisibile e senza ricostruire nulla.

Tenere separati i due evita di ricostruire il mondo ogni 2 km e di far “saltare” la mappa. Attenzione: il rebase **non** riduce l'errore di proiezione `d²/R`; quello dipende solo dall'anchor e si riduce con un nuovo anchor (o con un piano tangente più accurato).

### 6.3 Algoritmo di rebase

Soglia consigliata: **2048 m** (o 4096 m se si vuole meno lavoro; a 4096 m il passo float32 è 0,49 mm, comunque irrilevante). Il rebase si fa di preferenza all'inizio di `_physics_process`, prima di `move_and_slide`, e si spostano tutti i figli di un nodo `WorldRoot` che contiene mondo, player e camera.

```gdscript
const REBASE_RADIUS := 2048.0

var origin_e: float = 0.0   # 64-bit
var origin_n: float = 0.0

func maybe_rebase(px_e: float, pn_e: float) -> void:
    var de := px_e - origin_e
    var dn := pn_e - origin_n
    if absf(de) < REBASE_RADIUS and absf(dn) < REBASE_RADIUS:
        return

    # Traslazione rigida di tutto il contenuto.
    var shift := Vector3(de, 0.0, -dn)
    for child in world_root.get_children():
        if child is Node3D:
            child.position -= shift

    origin_e += de
    origin_n += dn

    # Le trasformazioni precedenti non sono più valide: evita lo "streak".
    # Node.reset_physics_interpolation() propaga anche ai figli.
    world_root.reset_physics_interpolation()
```

Note:

- Se camera e player sono figli di `WorldRoot`, si spostano insieme al mondo: la vista non cambia. Se la camera non è figlia, va spostata dello stesso `shift`.
- `world_root.reset_physics_interpolation()` è la chiamata documentata dopo un teleport/repentino cambio di trasformazione `[S14]`; va fatta **dopo** aver spostato i nodi.
- Non usare `world_root.position -= shift` come scorciatoia: è O(1) e la vista non cambia, ma i `position` locali dei figli crescono senza limite e la precisione peggiora. Lo shift esplicito dei figli è O(numero di chunk) ed è trascurabile.
- Se il rebase avviene mentre un `RigidBody3D` è attivo, il corpo potrebbe svegliarsi o interpolare male; nella slice i corpi dinamici sono solo il player. Spostare i corpi statici è sicuro.
- Dopo il rebase, `latlon_to_world()` usa il nuovo `origin_e/n`; non va toccato l'anchor della proiezione.

### 6.4 Perché non la build double precision

- Richiede ricompilare editor e export template con `precision=double`; i binari hanno suffisso `.double` e le estensioni GDExtension vanno ricompilate `[S12]`.
- La documentazione avverte di costo di performance e memoria, soprattutto su CPU a 32-bit, e che la feature è pensata per desktop medio-alto `[S12]`.
- La build double non elimina il problema del GPS né quello dei dati OSM; sposta solo il limite di precisione. Con il rebase e il frame locale, il float32 è già 1000× più preciso del GPS.
- La documentazione Godot dice esplicitamente che per un'area a piedi fino a 8192×8192 m il float32 basta `[S12]`; il progetto è dentro questo caso.

---

## 7. Passaggio a nuove zone

Ci sono due “nuove zone” diverse:

1. **Streaming di chunk** (centinaia di metri): stessa proiezione, stesso anchor, si caricano/scaricano chunk. Non è un cambio di coordinate.
2. **Cambio di zona di proiezione** (chilometri o città): nuovo anchor, nuova `M0/N0/cosφ0`, geometria ricostruita da lat/lon.

### 7.1 Regole

- **Anchor iniziale:** primo fix GPS con accuratezza accettabile (es. `accuracy ≤ 20 m`), oppure una posizione fissa di test per il fake GPS desktop. Per la slice va bene anche un anchor fisso (casa del tester) per rendere il mondo riproducibile.
- **Raggio di zona:** 4 km dall'anchor. A 4 km l'errore massimo orizzontale del piano tangente è ~1,25 m (lungo il meridiano ~1,2 cm), il passo float32 0,49 mm, l'abbassamento di curvatura 1,26 m (irrilevante con vista <1 km perché il terreno è piatto). 1,25 m è ancora sotto il GPS 3–5 m; a 8 km l'errore salirebbe a ~5 m, quindi il raggio 4 km è il compromesso. 4 km a piedi sono ~48 minuti: il cambio zona è raro.
- **Rebase:** ogni 2 km, come sopra. Il rebase non cambia l'anchor; si può fare quante volte si vuole.
- **Cambio anchor:** quando la distanza dall'anchor supera 4 km, o quando si cambia città/teleport. Si salvano le entità persistenti in lat/lon, si scarica il mondo, si crea un nuovo `GeoFrame` e si ricaricano i chunk intorno al giocatore. La geometria nuova è ricostruita da lat/lon, non traslata da coordinate mondo vecchie.
- **Persistenza:** ogni entità persistente (player, POI, eventuali oggetti) salva `lat`, `lon`, `alt` come `float` (64-bit) o come stringhe con 7 decimali. **Non salvare mai coordinate mondo** come stato persistente: cambiano con l'anchor e con il rebase.
- **Transizione visiva:** se il nuovo anchor è a 4 km, la vecchia proiezione aveva un errore assoluto di ~1,25 m; ricostruendo da lat/lon il mondo si riallinea al suolo vero, con uno shift globale di ~1,25 m. Poiché player, camera e geometria si spostano insieme, la vista **relativa** non cambia; il “pop” è solo il reload, non un mismatch locale. Per evitarlo, prefetchare la zona adiacente prima di attraversare il confine e fare un breve fade/loading. Per la slice, un fade è accettabile.
- **Città nuova:** scaricare tutto, nuovo `GeoFrame`, `origin_e/n = 0`, ricaricare. Non riusare le coordinate mondo della città precedente.

### 7.2 Perché non un'unica proiezione globale

- Un'unica proiezione tangente per tutta la Terra non è possibile: il piano tangente è locale per definizione.
- Un'unica proiezione Mercator globale sarebbe comoda per le tile, ma è sbagliata per i metri (§3.2) e il float32 a `y ≈ 5·10^6 m` ha passo 0,5 m, già visibile sul movimento a piedi.
- Un'unica ENU globale con ECEF avrebbe coordinate ~6,4·10^6 m e gli stessi problemi di precisione; servirebbe double ovunque.
- La combinazione “anchor locale + rebase + re-anchor alle zone” è il compromesso standard per open world a piedi.

---

## 8. Pseudocodice GDScript

Il codice seguente è **pseudocodice di riferimento**, non codice di gioco: mostra le funzioni e le invarianti da implementare. Gli identificatori sono in inglese, come da convenzione del repo.

### 8.1 GeoFrame

```gdscript
class_name GeoFrame
extends RefCounted

const A  := 6378137.0
const F  := 1.0 / 298.257223563
const E2 := 2.0 * F - F * F

var lat0: float
var lon0: float
var m0: float          # raggio meridiano all'anchor
var n0: float          # primo verticale all'anchor
var east_scale: float  # n0 * cos(lat0)
var north_scale: float # m0

func _init(lat: float, lon: float) -> void:
    set_anchor(lat, lon)

func set_anchor(lat: float, lon: float) -> void:
    lat0 = lat
    lon0 = lon
    var phi := deg_to_rad(lat)
    var s := sin(phi)
    var w := sqrt(1.0 - E2 * s * s)
    m0 = A * (1.0 - E2) / (w * w * w)
    n0 = A / w
    east_scale = n0 * cos(phi)
    north_scale = m0

func frame_e(lat: float, lon: float) -> float:
    var dlon := deg_to_rad(wrapf(lon - lon0, -180.0, 180.0))
    return east_scale * dlon

func frame_n(lat: float, lon: float) -> float:
    var dlat := deg_to_rad(lat - lat0)
    return north_scale * dlat

# Restituisce la posizione locale già relativa al render origin.
func to_world(lat: float, lon: float, alt: float,
              origin_e: float, origin_n: float) -> Vector3:
    var e := frame_e(lat, lon) - origin_e
    var n := frame_n(lat, lon) - origin_n
    return Vector3(e, alt, -n)

func from_world(p: Vector3, origin_e: float, origin_n: float) -> Array:
    var e := p.x + origin_e
    var n := -p.z + origin_n
    var lat := lat0 + rad_to_deg(n / m0)
    var lon := lon0 + rad_to_deg(e / east_scale)
    return [lat, lon] # due float, non Vector2: Vector2 è 32-bit
```

Nota: `Array` come ritorno è comodo per il pseudocodice; in produzione si può usare una piccola classe `GeoPoint` con due `float`, o due variabili `out`. Non usare `Vector2` per lat/lon: a 45° il passo float32 è ~4·10⁻⁶°, cioè ~0,4 m `[S13]`.

### 8.2 Tile XYZ

```gdscript
func lonlat_to_tile(lat: float, lon: float, z: int) -> Vector2i:
    lat = clampf(lat, -85.05112878, 85.05112878)
    var n := 1 << z
    var x := int(floor((lon + 180.0) / 360.0 * n))
    var lat_rad := deg_to_rad(lat)
    var y := int(floor((1.0 - asinh(tan(lat_rad)) / PI) / 2.0 * n))
    return Vector2i(clampi(x, 0, n - 1), clampi(y, 0, n - 1))

func tile_lon_w(x: int, z: int) -> float:
    var n := float(1 << z)
    return x / n * 360.0 - 180.0

func tile_lat_n(y: int, z: int) -> float:
    var n := float(1 << z)
    return rad_to_deg(atan(sinh(PI * (1.0 - 2.0 * y / n))))

# Rettangolo mondo della tile, relativo al render origin.
func tile_world_rect(z: int, x: int, y: int,
                     f: GeoFrame, origin_e: float, origin_n: float) -> Rect2:
    var lon_w := tile_lon_w(x, z)
    var lon_e := tile_lon_w(x + 1, z)
    var lat_n := tile_lat_n(y, z)
    var lat_s := tile_lat_n(y + 1, z)

    var e0 := f.frame_e(lat_n, lon_w)
    var n0 := f.frame_n(lat_n, lon_w)
    var e1 := f.frame_e(lat_s, lon_e)
    var n1 := f.frame_n(lat_s, lon_e)

    var p0 := Vector2(e0 - origin_e, -(n0 - origin_n))
    var p1 := Vector2(e1 - origin_e, -(n1 - origin_n))
    return Rect2(p0, p1 - p0) # p1.x > p0.x, p1.y > p0.y (sud = +Z)
```

`asinh`, `sinh`, `atan2`, `wrapf`, `deg_to_rad` sono funzioni globali di Godot 4 `[S21]`.

### 8.3 Mesh di una tile

```gdscript
# p_nw, p_ne, p_se, p_sw sono Vector3 nel frame locale (già con -origin).
# Ordine scelto per avere normale +Y (su); per il terreno usare cull_mode = disabled.
func build_tile_quad(p_nw: Vector3, p_ne: Vector3, p_se: Vector3, p_sw: Vector3,
                     tex: Texture2D) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    st.set_uv(Vector2(0, 0)); st.add_vertex(p_nw)
    st.set_uv(Vector2(0, 1)); st.add_vertex(p_sw)
    st.set_uv(Vector2(1, 1)); st.add_vertex(p_se)

    st.set_uv(Vector2(0, 0)); st.add_vertex(p_nw)
    st.set_uv(Vector2(1, 1)); st.add_vertex(p_se)
    st.set_uv(Vector2(1, 0)); st.add_vertex(p_ne)

    st.generate_normals()
    return st.commit()
```

Con questo ordine la normale geometrica è `+Y`. Se il materiale del terreno usa il culling di default e la tile scompare, disabilitare il culling (`cull_mode = disabled`): è la soluzione più semplice e sicura per un piano orizzontale. Per le pareti degli edifici, invece, il winding va verificato singolarmente.

### 8.4 GPS update + rebase

```gdscript
func _physics_process(_delta: float) -> void:
    var fix := gps.latest_fix() # {lat, lon, alt, accuracy, time}
    if fix == null or fix.accuracy > 50.0:
        return

    var pe := frame.frame_e(fix.lat, fix.lon)
    var pn := frame.frame_n(fix.lat, fix.lon)
    maybe_rebase(pe, pn) # può spostare il mondo; player/camera sono figli di WorldRoot

    var p := frame.to_world(fix.lat, fix.lon, 0.0, origin_e, origin_n)
    player.position = p # oppure il target dello smoothing del ticket 07
```

### 8.5 Cambio zona

```gdscript
const ZONE_RADIUS := 4096.0

func maybe_new_zone(lat: float, lon: float) -> void:
    var e := frame.frame_e(lat, lon)
    var n := frame.frame_n(lat, lon)
    if sqrt(e * e + n * n) < ZONE_RADIUS:
        return

    save_persistent_as_latlon()   # player, POI, oggetti: solo lat/lon/alt
    unload_all_chunks()
    frame = GeoFrame.new(lat, lon) # nuovo anchor
    origin_e = 0.0
    origin_n = 0.0
    load_chunks_around(lat, lon)
```

Per una transizione senza pop: prefetch dei chunk della zona adiacente prima di superare il raggio, poi fade e swap. Per la slice, un breve fade è sufficiente.

---

## 9. Budget degli errori attesi

| Fonte | Entità tipica | Impatto sulla posizione/percepito |
|---|---|---|
| GPS orizzontale | 3–5 m cielo aperto; 10–30 m città (fino a centinaia in casi estremi) `[S7][S8]` | **dominante**; jitter da fermo, salti tra edifici |
| GPS altitudine | 10–30 m, ellissoidica | inutilizzabile per il terreno; usare `y=0` |
| Proiezione tangente | lungo il meridiano: 3 mm a 2 km, 5 cm a 8 km; caso peggiore a distanza `d`: ~0,31 m a 2 km, ~1,25 m a 4 km, ~5 m a 8 km | trascurabile fino a ~4 km; a 8 km confrontabile col GPS |
| Float32 locale | 0,24 mm a 2 km; 1 mm a 8 km | trascurabile |
| Double globale | ~10⁻⁹ m | trascurabile |
| Raster z18 | ~0,42 m/px a 45° `[S4]` | dettaglio del terreno |
| Raster z19 | ~0,21 m/px a 45° `[S4]` | dettaglio del terreno |
| Generalizzazione raster | 1–2 px | 0,4–0,8 m a z18 |
| Offset imagery satellite | metri | non usare per validare la proiezione |
| Footprint OSM | metri | errore dei dati, non della proiezione |
| Mercator grezzo | 30–45% in Italia | da evitare |
| Mercator × `cosφ` | 1,7 m/km, 3,7 m a 2 km | sufficiente per un prototipo, non per “1 m = 1 unit” |
| Tile 512 px scambiata per 2× | 2× | da evitare |
| TMS non convertito | mappa specchiata | da evitare |

**Conclusione del budget:** con il piano tangente, a 2 km l'errore è ~3 mm lungo il meridiano e ~0,31 m nel caso peggiore; il float32 ~0,24 mm; il GPS 3–5 m. Fino a ~4 km il collo di bottiglia è il GPS; a 8 km la proiezione (~5 m) diventa comparabile, quindi non allargare il raggio di zona oltre ~4 km. In quadratura, a 4 km con GPS 4 m e proiezione 1,25 m l'errore totale è ~4,2 m; a 8 km è ~6,4 m. Il ticket 07 (smoothing) è più importante di qualsiasi raffinamento geodetico.

---

## 10. Test e criteri di accettazione

### 10.1 Unit test (desktop, senza GPS)

1. **Tile di riferimento OSM:** `(lat=35.6590699, lon=139.7006793, z=18)` deve dare `tile (232798, 103246)`; è l'esempio della statua di Hachiko nella wiki OSM `[S1]`.
2. **Bordi tile:** per `z=18, x=232798, y=103246`, `lat_n ≈ 35.6595278649`, `lon_w ≈ 139.6994018555`, `lat_s ≈ 35.6584120643`, `lon_e ≈ 139.7007751465`.
3. **Scale locali di 1°:** all'equatore `1° lon = 111319.4908 m`; a 45° `1° lat = 111131.7774 m`, `1° lon = 78846.8351 m`; a 41° `1° lat = 111053.9079 m`, `1° lon = 84135.1851 m`. Sono `M0·π/180` e `N0 cosφ0·π/180`, non l'arco geodesico esatto su 1° (che differisce di frazioni di metro per la variazione di `M`/`N`).
4. **Anchor:** `to_world(lat0, lon0, 0, 0, 0) == Vector3.ZERO`.
5. **1 km nord:** `to_world(lat0 + 1000/m0·180/π, lon0, 0, 0, 0).z ≈ −1000` entro 1 mm.
6. **1 km est:** `to_world(lat0, lon0 + 1000/(n0 cosφ0)·180/π, 0,0,0).x ≈ 1000` entro 1 mm. La componente N dello stesso punto è ~−0,078 m: è la curvatura del parallelo, non un errore di implementazione.
7. **Round-trip:** `from_world(to_world(lat, lon, alt, o_e, o_n), o_e, o_n)` restituisce lat/lon entro 1e-7°.
8. **Rebase:** dopo `maybe_rebase`, la posizione geografica del player è invariata; la sua posizione locale è ~0; `to_world` con il nuovo origin restituisce lo stesso punto geografico.
9. **Tile/building alignment:** un vertice noto di un edificio OSM e il pixel corrispondente della tile (stessa lat/lon) devono cadere nello stesso punto mondo entro 10 cm nel raggio di 1 km (l'errore di proiezione a 1 km è ~8 cm nel caso peggiore; a 500 m ~2 cm).
10. **512 vs 256:** la stessa tile a 512 px deve avere lo stesso `W × H` della 256 px; cambia solo la texture.

### 10.2 Field test (Fairphone Gen 6)

- Camminare 1 km in linea retta e verificare che l'avatar resti centrato sulla strada/texture senza drift sistematico.
- Fermarsi 60 s e misurare il jitter residuo: deve essere compatibile con l'accuracy GPS, non amplificato dalla proiezione.
- Attraversare un confine di tile e uno di chunk: nessun seam visibile, nessun salto.
- Superare i 2 km dall'anchor: il rebase non deve produrre scatti visibili.
- Simulare un salto GPS di 5 km (fake GPS): il rebase deve essere immediato e senza “streak”.
- Confrontare un angolo di edificio noto con la tile: offset atteso dell'ordine del GPS/dati OSM, non della proiezione.

### 10.3 Criteri

- Nessun jitter attribuibile al float32 o alla proiezione.
- Offset raster/edifici visivamente < 1 m nel raggio di 500 m.
- Rebase invisibile e O(chunk), non O(vertices).
- Cambio zona con prefetch < 1 s percepito, senza buchi neri oltre il fade.
- Il codice di conversione non usa mai `Vector2`/`Vector3` per lat/lon o per coordinate globali.

---

## 11. Rischi e questioni aperte

1. **Provider tile non EPSG:3857.** Alcuni provider offrono stili o proiezioni diverse. Il ticket 03 deve confermare che le tile sono XYZ/Web Mercator; se no, cambiano le formule dei bounds, non il piano tangente.
2. **Tile con bordo/overlap.** Alcuni provider aggiungono un bordo di 1 px o un overlap; va verificato, altrimenti il bordo della tile non coincide con il bounds geografico.
3. **Dati OSM incompleti o offset.** Footprint mancanti, edifici fuori scala, strade non allineate: sono problemi di dati, non di coordinate. La slice deve degradare in modo controllato (edificio assente = nessun volume).
4. **Terreno non piatto.** La slice è piatta; in futuro servirà un DEM e una quota locale. Non usare l'altitudine GPS come quota del terreno.
5. **Multiplayer futuro.** Un frame locale per client richiede un frame condiviso o coordinate geodetiche per la sincronizzazione. La scelta “persisti lat/lon” è già compatibile.
6. **Vector tile futuri.** MVT è in Web Mercator; la stessa pipeline di conversione tile→tangent vale, cambia solo la fonte della geometria.
7. **Antimeridiano e poli.** Non rilevanti per l'Italia, ma `wrapf` e il clamp a ±85.05° vanno messi fin dall'inizio.
8. **Attribuzione OSM.** La tile policy OSM richiede attribuzione visibile e cache `[S20]`; è responsabilità del ticket 03/05, non della proiezione.

---

## 12. Fonti

Tutte le fonti sono state consultate il **2026-10-31**. Le fonti OSM Wiki sono documentazione comunitaria primaria per formati e tag OSM; le fonti EPSG/IOGP, Godot, GeographicLib, Khronos e Android sono documentazione ufficiale.

- **[S1]** OpenStreetMap Wiki, *Slippy map tilenames* — formule lat/lon ↔ tile, 256/512 px, esempio Hachiko. https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames
- **[S2]** EPSG.io / EPSG Registry, *EPSG:3857 — WGS 84 / Pseudo-Mercator* — WKT, parametri WGS84, remark su errori 0,7% / 43 km. https://epsg.io/3857
- **[S3]** EPSG.io / IOGP, *EPSG:1024 — Popular Visualisation Pseudo Mercator* — formule, fattori `h`/`k`, non conformità, distorsione angolare; trascrizione di IOGP Guidance Note 7-2. https://epsg.io/1024-method ; documento originale: https://www.iogp.org/wp-content/uploads/2019/09/373-07-02.pdf
- **[S4]** OpenStreetMap Wiki, *Zoom levels* — formula metri/pixel, tabella zoom. https://wiki.openstreetmap.org/wiki/Zoom_levels
- **[S5]** OpenStreetMap Wiki, *TMS* — Y invertita rispetto a XYZ. https://wiki.openstreetmap.org/wiki/TMS
- **[S6]** OpenStreetMap Wiki, *Precision of coordinates* — 7 decimali ≈ 1,1 cm; dipendenza da `cosφ`. https://wiki.openstreetmap.org/wiki/Precision_of_coordinates
- **[S7]** OpenStreetMap Wiki, *Accuracy of GNSS data* — precisione tipica, multipath, ambiente urbano. https://wiki.openstreetmap.org/wiki/Accuracy_of_GNSS_data
- **[S8]** Android Developers, *Location* — `getAccuracy()` al 68° percentile, altitudine sopra l'ellissoide WGS84. https://developer.android.com/reference/android/location/Location
- **[S9]** OpenStreetMap Wiki, *Simple 3D Buildings* — `height`, `min_height`, `building:levels`, `building:part`. https://wiki.openstreetmap.org/wiki/Simple_3D_Buildings
- **[S10]** OpenStreetMap Wiki, *Key:height* — unità metri, altezza massima dell'edificio. https://wiki.openstreetmap.org/wiki/Key:height
- **[S11]** OpenStreetMap Wiki, *Overpass API* — query e output `out geom` con geometria lat/lon. https://wiki.openstreetmap.org/wiki/Overpass_API
- **[S12]** Godot Engine 4.7 docs, *Large world coordinates* — precisione float32, tabella, 8192×8192 m a piedi, origin shifting, build `precision=double`. https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html
- **[S13]** Godot Engine 4.7 docs, *Vector3* — 32-bit di default, `float` 64-bit, costanti `FORWARD`/`BACK` (nord/sud). https://docs.godotengine.org/en/stable/classes/class_vector3.html
- **[S14]** Godot Engine 4.7 docs, *Node* — `reset_physics_interpolation()`. https://docs.godotengine.org/en/stable/classes/class_node.html
- **[S15]** Godot Engine 4.7 docs, *Node3D* — `global_position`, `position`, trasformazioni locali/globali. https://docs.godotengine.org/en/stable/classes/class_node3d.html
- **[S16]** Godot Proposals, *Add support for double precision floats #892* — jitter a pochi km, target di 0,5 mm, origin shifting come workaround. https://github.com/godotengine/godot-proposals/issues/892
- **[S17]** GeographicLib, *LocalCartesian* — definizione ENU, origine tangente, y nord, z normale all'ellissoide. https://geographiclib.sourceforge.io/C++/doc/classGeographicLib_1_1LocalCartesian.html
- **[S18]** GeographicLib, *Geocentric* — ECEF, WGS84, accuratezza. https://geographiclib.sourceforge.io/C++/doc/classGeographicLib_1_1Geocentric.html
- **[S19]** Khronos, *glTF 2.0 Specification*, §3.4 Coordinate System and Units — “The units for all linear distances are meters”. https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#coordinate-system-and-units
- **[S20]** OpenStreetMap Foundation, *Tile Usage Policy* — attribuzione, cache, URL. https://operations.osmfoundation.org/policies/tiles/
- **[S21]** Godot Engine 4.7 docs, *@GlobalScope* — `asinh`, `sinh`, `atan2`, `wrapf`, `deg_to_rad`. https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html

---

## Appendice A — Derivazione dei fattori `h`/`k` e relazione col piano tangente

Dalla definizione EPSG del metodo 1024 `[S3]`:

```
h = R / (ρ cosφ)
k = R / (ν cosφ)
ρ = a(1 − e²)/(1 − e² sin²φ)^(3/2) = M(φ)
ν = a/(1 − e² sin²φ)^(1/2) = N(φ)
```

Un delta di Mercator `Δx` corrisponde a un delta di longitudine `Δλ = Δx/R`; il corrispondente arco di parallelo al suolo è `N cosφ Δλ`:

```
ΔE_ground = N cosφ · (Δx / R) = Δx / k
```

Analogamente, per un delta di northing `Δy`, il primo ordine dà `ΔN_ground = Δy / h` **solo se** si valuta la scala alla latitudine del punto. Valutando `h0` all'anchor, `Δy/h0` include la nonlinearità di Mercator (`secφ`): a 2 km nord a 45° sovrastima di ~0,31 m. Per questo il piano tangente usa direttamente `M0 Δφ`, non `Δy/h0`. Se si parte da coordinate Mercator, conviene invertirle in lat/lon e poi applicare `M0,N0`; oppure usare `Δy/h(φ)` punto per punto, che è più costoso.

La formula `E = N0 cosφ0 Δλ`, `N = M0 Δφ` è quindi la linearizzazione corretta all'anchor, non un “Mercator scalato”.

---

## Appendice B — ENU esatto (per test e validazione)

```gdscript
# PackedFloat64Array: ECEF e ENU possono superare i 6·10^6 m, dove Vector3
# (32-bit) avrebbe un passo di 0,5 m e falserebbe il test.
func ecef(lat_deg: float, lon_deg: float, h: float) -> PackedFloat64Array:
    var phi := deg_to_rad(lat_deg)
    var lam := deg_to_rad(lon_deg)
    var s := sin(phi)
    var w := sqrt(1.0 - E2 * s * s)
    var n := A / w
    var x := (n + h) * cos(phi) * cos(lam)
    var y := (n + h) * cos(phi) * sin(lam)
    var z := (n * (1.0 - E2) + h) * s
    return PackedFloat64Array([x, y, z])

func enu_of(lat_deg: float, lon_deg: float, h: float,
            lat0: float, lon0: float, h0: float) -> PackedFloat64Array:
    var p := ecef(lat_deg, lon_deg, h)
    var p0 := ecef(lat0, lon0, h0)
    var dx := p[0] - p0[0]
    var dy := p[1] - p0[1]
    var dz := p[2] - p0[2]
    var phi0 := deg_to_rad(lat0)
    var lam0 := deg_to_rad(lon0)
    var e := -sin(lam0) * dx + cos(lam0) * dy
    var n := -sin(phi0) * cos(lam0) * dx - sin(phi0) * sin(lam0) * dy + cos(phi0) * dz
    var u :=  cos(phi0) * cos(lam0) * dx + cos(phi0) * sin(lam0) * dy + sin(phi0) * dz
    return PackedFloat64Array([e, n, u]) # e=est, n=nord, u=up
```

Questo è solo per i test: il runtime usa il piano tangente. Le differenze attese sono nella tabella §3.5. Se si usa `Vector3` qui, il passo float32 a 6,4·10^6 m è 0,5 m e il test “esatto” non misura più la proiezione, ma la precisione del contenitore.

---

## Appendice C — Numeri di controllo

Calcoli eseguiti in fase di ricerca con le formule di questo documento (WGS84, `a=6378137`, `1/f=298.257223563`):

- `M(45°) = 6367381.816 m`, `N(45°) = 6388838.290 m`.
- `h0(45°) = 1.416602`, `k0(45°) = 1.411845`, `h/k = 1.003370`, `ω = 0.1928°`.
- `M(41°) = 6362920.220 m`, `N(41°) = 6387345.731 m`, `h0 = 1.328182`, `k0 = 1.323103`.
- `M(46°) = 6368501.438 m`, `N(46°) = 6389212.733 m`, `h0 = 1.441735`, `k0 = 1.437061`.
- Tile z18 a 45°: `2πR/2^18 = 152.874057 m` in Mercator; `W = 108.2797 m`, `H = 107.9160 m`.
- Tile z18 a 41°: `W = 115.5421 m`, `H = 115.1003 m`.
- Hachiko z18: tile `(232798, 103246)`, `W = 124.3517 m`, `H = 123.8011 m`.
- Passo float32 a 2 km: `0.000244141 m`; a 8 km: `0.000976562 m`.
- Piano tangente vs ENU esatto, componente N a 2 km nord: `−0.003132 m`; componente E a 2 km est: `+0.000065 m`; componente N a 8 km nord: `−0.048530 m`. Attenzione: a 2 km est la componente N è `−0.314 m`; a 2 km nord-est (1.414 km, 1.414 km) l'errore E è `+0.313 m`. Sono gli errori di curvatura del piano tangente, non errori di formula.
- Mercator × `cosφ0` vs ENU esatto a 2 km nord: `+3.689811 m`; a 2 km est: `−3.349930 m`.
