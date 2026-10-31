# OSM → scena 3D low-poly in Godot 4.7 mobile

**Ticket:** 02 · **Data:** 2026-10-31 · **Target:** Godot 4.7.2 mobile, Android 16, Fairphone Gen 6

## TL;DR — decisione

Per la vertical slice raccomando **l'opzione A: terreno raster da tile XYZ + edifici estrusi dai footprint OSM via Overpass**, con queste scelte obbligatorie:

- tile raster a **z17** (fallback z16), **256 px**, chunk allineati a **2×2 tile** (~430 m a latitudine italiana);
- edifici raggruppati in **una `ArrayMesh` per chunk** (pareti + tetti, vertex color, un solo materiale), non un nodo per edificio;
- parsing Overpass e costruzione delle mesh su **worker thread**; upload di texture/mesh sul main thread;
- cache su disco con TTL (≥7 giorni per le tile, 7–30 giorni per gli edifici), LRU e limite di memoria;
- attribuzione OSM visibile e permanente.

MVT custom (opzione B) è il **piano di evoluzione** quando la scala supera il tester singolo o servono terreno vettoriale, etichette e aggiornamenti più controllati. Gli SDK/plugin esistenti (opzione C: MapLibre Native, Cesium/3D Tiles) **non sono utilizzabili oggi per una scena 3D low-poly integrata in Godot su Android**: i plugin Godot sono desktop-only, deprecati o non integrano il 3D di gioco.

I tre rischi che possono far fallire la slice sono: **limiti/latenza di Overpass pubblico**, **altezze OSM mancanti o sbagliate**, **memoria delle texture runtime non compresse** su mobile.

---

## 1. Metodo, perimetro e limiti

Ho usato fonti primarie:

- policy OSMF per tile raster e vettoriali, linee guida di attribuzione, licenza ODbL;
- wiki OSM per Overpass, Simple 3D Buildings, slippy map tile names;
- specifica Mapbox Vector Tile 2.1;
- schema OpenMapTiles e Shortbread, con i loro SQL/YAML;
- documentazione Godot 4.7 (renderer, `ArrayMesh`, `Geometry2D`, `HTTPRequest`, `Image`, `WorkerThreadPool`, thread-safety, performance mobile);
- repository e README dei plugin candidati (MapLibre Native, `maplibre-native-godot`, 3D Tiles for Godot, Cesium for Godot, `godot-geo-tile-loader`, `3D-OSM-GODOT`);
- dati taginfo OSM al 2026-10-31;
- tre misure locali del 2026-10-31: una query Overpass, una tile OpenFreeMap, una tile Shortbread (dettagli in appendice).

Le misure servono a dare ordini di grandezza, non sono un benchmark: Overpass e i provider hanno carico variabile, e i dati OSM cambiano continuamente. Questo documento non è un parere legale: le licenze vanno riviste prima di distribuire dati o cache OSM-derived.

---

## 2. Requisiti e vincoli della slice

Dal progetto e dalla mappa:

- Godot 4.7.2, renderer **Mobile**, Jolt Physics, target Android 16 su Fairphone Gen 6 [S50][S51].
- Vertical slice in portrait, camera obliqua fissa **north-up**, stile low-poly in stile Pokémon GO, avatar su mappa OSM con terreno e edifici estrusi vicino al giocatore [S51].
- Streaming e cache dinamici, attribuzione OSM visibile, provider tile con API key free-tier [S51].
- Niente POI, catture, backend, iOS, AR; la mappa produce decisioni, non la slice [S51].

Chiarimento importante: **“terreno raster da tile XYZ” significa una texture applicata a un piano**, non un modello di elevazione. Le tile XYZ sono immagini colorate; non contengono quote. Per rilievo reale servirebbe un DEM separato (es. Terrarium/Mapzen), fuori scope per una città piatta. La slice può quindi assumere terreno a `y = 0` e dedicare il budget a edifici, streaming e camera.

Vincoli tecnici del renderer Mobile:

- è pensato per dispositivi mobili recenti con Vulkan/D3D12/Metal; non ha SSAO, SDFGI, SSR, VoxelGI, TAA e altre feature del Forward+ [S1].
- l’instancing automatico delle mesh è solo Forward+; su Mobile bisogna unire le mesh o usare `MultiMesh` [S2].
- il costo dominante su mobile è spesso fill rate/overdraw, non il numero di vertici; vanno evitati tanti piccoli oggetti e molta trasparenza [S3].
- le texture caricate a runtime da PNG restano **non compresse**: `Image.compress()` è disponibile solo nell’editor, non nel progetto esportato [S4].

---

## 3. Opzione A — Raster XYZ + edifici estrusi da Overpass

### 3.1 Pipeline

1. Dal GPS si ottiene lat/lon; si proietta in Web Mercator/locale metri (ticket 04).
2. Un **chunk** è un blocco di tile z17 (es. 2×2 tile, ~430 m di lato a latitudine italiana).
3. Per ogni tile del chunk si scarica il PNG dal provider scelto (ticket 03), si decodifica con `Image.load_png_from_buffer()`, si crea una `ImageTexture` e si applica a un quad che copre esattamente i bounds della tile [S5][S6].
4. Per il bbox del chunk (con margine ~20 m) si interroga Overpass per `building` e `building:part`, output `out geom` [S7][S8].
5. Il JSON viene parsato e i footprint vengono proiettati nello stesso sistema locale delle tile.
6. Ogni footprint viene estruso: pareti verticali + tetto, con altezza da `height`, altrimenti `building:levels × 3.0/3.66`, altrimenti un default (es. 8 m) [S9][S10].
7. Tutte le geometrie del chunk vengono unite in una `ArrayMesh` con vertex color e un solo `StandardMaterial3D`; un `MeshInstance3D` per chunk [S11][S12].
8. Il chunk viene caricato/scaricato con priorità, prefetch ring 1, cache LRU.

### 3.2 Qualità visiva

**Punti forti**

- I footprint Overpass sono alla risoluzione OSM, non alla risoluzione della tile vettoriale: a z17 il terreno ha ~0.84 m/px a latitudine 45°, mentre un edificio di 20 m occupa ~24 px. I contorni possono essere fedeli e “low-poly” quanto si vuole, semplificandoli con una tolleranza.
- I dati di altezza, pur sparsi, sono letti direttamente da OSM: `height`, `min_height`, `building:levels`, `building:min_level`, `roof:shape` [S9]. Si può fare un low-poly credibile con tetti piatti e colori per tipo.
- Terreno e edifici vengono dalla stessa fonte OSM, quindi strade e footprint sono generalmente allineati; il rischio di mismatch è soprattutto temporale (snapshot della tile vs query live), non proiettivo.

**Limiti**

- Il terreno è piatto e la texture può contenere etichette, POI e ombre già “disegnate” dal provider. Per lo stile low-poly conviene uno **stile senza etichette o con etichette minime**, colori piatti e nessuna ombreggiatura baked (ticket 03). Le etichette baked, viste in obliquo, si allungano e confliggono con il 3D.
- Le altezze OSM sono **sparse**: al 2026-10-31 ci sono ~713 milioni di elementi con `building=*`, ma solo ~28 milioni con `height` e ~44 milioni con `building:levels` [S13][S14]. Sono conteggi di tag, non edifici unici, e includono anche elementi non-edificio: la copertura reale delle altezze è quindi una frazione minoritaria. La maggior parte degli edifici userà un’altezza di fallback.
- I footprint possono essere group outline, multipolygon con cortili, o edifici con `building:part`; la qualità varia [S15]. Un outline che contiene parti non va estruso se ci sono parti 3D: la regola Simple 3D Buildings dice che l’outline non è considerato per il 3D quando esistono `building:part` [S9].
- Un edificio a cavallo di due chunk può essere duplicato o tagliato; va gestito con margine, assegnazione per centroide e `custom_aabb`, oppure accettando un piccolo popping.

### 3.3 Complessità

**Media-bassa**, tutta con API Godot standard:

- HTTP e PNG: `HTTPRequest`, `Image`, `ImageTexture` [S5][S6].
- Geometria: proiezione, triangolazione con `Geometry2D.triangulate_polygon()`, generazione di pareti/tetti, `ArrayMesh` [S8][S11].
- JSON: `JSON.parse_string()`; parsing e costruzione mesh su `WorkerThreadPool` [S16][S17].
- Cache: `FileAccess`/`DirAccess`.

Non serve implementare un decoder protobuf, un motore di stile MVT, il label placement o le regole di clipping delle tile vettoriali. Il grosso del lavoro è **robustezza geometrica** (anelli invalidi, buchi, parti, altezze sporche), non il rendering.

### 3.4 Performance mobile

- **Draw call**: 4 quad di terreno per chunk (2×2 tile) + 1 mesh edifici per chunk. Con 3×3 chunk visibili: ~36 quad + 9 mesh = ~45 draw call, più avatar/HUD. È un budget sano per Mobile.
- **Triangoli**: un edificio low-poly semplice (prisma a base rettangolare) è ~20–30 triangoli; 1.000 edifici visibili sono ~20–30k triangoli. Il collo di bottiglia non è il vertex count, ma fill rate e piccoli triangoli concentrati [S3].
- **Texture**: una tile 256×256 RGBA8 è 256 KiB; 36 tile visibili sono ~9 MiB (più mipmap). A 512 px diventano ~36 MiB. Le texture runtime non sono comprimibili in export [S4], quindi il limite di cache in RAM è la scelta più importante.
- **Upload**: la creazione di `ImageTexture` e l’upload di mesh vanno sul main thread; il thread worker prepara solo array e dati [S18].
- **Nessuna ombra realtime** o, al massimo, una directional light con shadow map piccola: le ombre sono costose su mobile [S3]. Per il look low-poly basta shading per faccia/vertex color.

### 3.5 Licenze

- **Dati OSM**: ODbL 1.0; attribuzione obbligatoria e, se si distribuisce un database derivato, share-alike [S19][S20][S21]. Un’opera prodotta (la scena renderizzata) richiede l’attribuzione, non automaticamente il share-alike; la cache locale di dati OSM resta un tema da verificare legalmente [S20].
- **Tile raster**: la policy di `tile.openstreetmap.org` vieta bulk download/offline, richiede User-Agent identificabile, cache ≥7 giorni e attribuzione; niente SLA [S22]. **Non va usata in produzione** per un’app che preloada o cachea per il gioco. Il provider scelto in ticket 03 deve consentire caching/streaming e l’uso in un’app mobile.
- **Overpass API**: il software server è AGPL-3.0; l’uso dell’API non implica di per sé che il client debba essere AGPL, ma il punto va verificato legalmente. I dati restano ODbL e la policy pubblica limita l’uso [S7].
- **Codice Godot**: MIT; nessun vincolo aggiuntivo sul rendering.

### 3.6 Copertura dati

- Copertura globale dove OSM ha edifici; ottima nei centri urbani europei, variabile in periferia e aree rurali.
- Altezze e parti 3D sono il vero buco: la maggior parte degli edifici non ha `height`; `building:part` è raro (~4.9 milioni di elementi) [S14].
- Le tile raster del provider coprono globalmente, ma la qualità dello stile e la presenza di etichette dipendono dal provider.

### 3.7 Streaming

- Le tile XYZ sono il caso più semplice: URL deterministico, cache per `z/x/y`, supporto nativo a HTTP caching, prefetch ring 1, fallback a tile padre (z16/z15) mentre si carica z17.
- Overpass non è un tile server: è una query per bbox. Va trattata come **sorgente lenta e rate-limited**, con cache su disco e caricamento progressivo. La query di prova (bbox ~220×235 m, centro Milano) è tornata in **29 s** con **15,8 KB** e 14 elementi: il tempo è dominato dal carico del server, non dal payload [misura A].
- La policy Overpass per uso regolare suggerisce di stare sotto **100 query/giorno e 10 MB/giorno** (i limiti “una tantum” sono 10.000 query/1 GB/10 minuti, ma per un’app si dividono per 100; l’uso di tutti gli utenti si somma) [S7]. Una passeggiata di 1 km con chunk da 430 m può generare 10–20 query: va bene per un tester, non per una release pubblica.

---

## 4. Opzione B — Vector tile MVT con rendering custom o plugin

### 4.1 Cosa sono e cosa contengono

MVT è un formato protobuf con layer, feature, geometrie a comandi (`MoveTo`, `LineTo`, `ClosePath`) in coordinate intere con `extent` (tipicamente 4096) [S23]. Il client deve decodificare, ricostruire i poligoni, applicare uno stile, tassellare e disegnare. Non è un’immagine: è un dataset.

Gli schemi più diffusi:

- **OpenMapTiles** (MapTiler, Stadia, OpenFreeMap): layer `building` con `render_height`, `render_min_height`, `colour`, `hide_3d`; altezza calcolata come `ceil(COALESCE(height, levels * 3.66, 5))` e base `floor(COALESCE(min_height, min_level * 3.66, 0))` [S24][S25]. Include tutti gli edifici OSM, esclusi gli underground.
- **Shortbread** (OSMF `vector.openstreetmap.org`, Geofabrik, VersaTiles): layer `buildings` con **solo** una proprietà `dummy=1`, nessuna altezza, nessun ID per edificio [S26]. Massimo zoom 14 [S26].

### 4.2 Misure fatte

- Tile OpenFreeMap z14/8610/5863 (Milano centro, ~1.7 km di lato): **620.352 byte**, layer `building` con **67 feature** ma **2.959 anelli**; una sola feature conteneva **1.414 anelli**. Tutte le 67 feature avevano `render_height` [misura B]. Questo conferma che Planetiler (profilo OpenMapTiles) **fonde feature con gli stessi attributi** (“merge nearby lines or polygons with the same tags”) [S27]: non si può assumere “una feature = un edificio”. Gli anelli vanno estratti e estrusi singolarmente.
- Tile Shortbread z14/8610/5863: **424.265 byte**, layer `buildings` con **una sola feature**, **62.071 interi di geometria** e **nessun attributo** [misura C]. Non è utilizzabile per altezze, colori per edificio o identificazione; al massimo come base per un fill piatto.

### 4.3 Qualità visiva

**Punti forti**

- Geometria vettoriale nitida a qualsiasi zoom, stile completamente controllabile, terreno vettoriale (landuse, acqua, strade) coerente con gli edifici.
- OpenMapTiles fornisce altezze approssimate e colori, quindi si possono estrudere edifici senza Overpass.
- Niente etichette baked nel terreno: le etichette si possono omettere o disegnare in 3D/2D in modo controllato.

**Limiti**

- **Max zoom 14** per OpenMapTiles/Shortbread: OpenFreeMap dichiara `maxzoom: 14` nel tilejson [S31] e Shortbread ha max zoom 14 [S26]; a z17 si fa overzoom di geometria semplificata a z14. A latitudine 45, z14 ha ~6.7 m/px: un edificio di 20 m è ~3 px; a z17 è ~24 px. I contorni saranno molto più grossolani dei footprint Overpass.
- Le feature sono **fuse per attributi** (misura B); serve un lavoro di esplosione degli anelli e di gestione dei buchi.
- Shortbread non ha altezze: inutile per l’estrusione “vera”; andrebbe incrociato con Overpass o con un altro schema.
- I bordi delle tile tagliano gli edifici; servono buffer, clipping e gestione delle cuciture. Un edificio a cavallo di due tile può avere pareti doppie o z-fighting.

### 4.4 Complessità

**Alta**:

- decoder protobuf + decoder geometria MVT;
- ricostruzione di anelli esterni/interni, orientamento, buchi, multipolygon;
- tassellazione e generazione pareti/tetti;
- stile (filtri, colori, zoom, LOD), clipping, label placement se si fa terreno vettoriale;
- cache e priorità.

Plugin esistenti:

- `godot-geo-tile-loader` (Rust GDExtension) è fermo dal 2023, non ha binari Android e non ha un LICENSE top-level; il parser GDScript incluso `vector_tile.gd` è BSD-3-Clause e può essere riusato come riferimento [S28].
- `3D-OSM-GODOT` è un progetto studentesco MIT, Godot 4.1 Forward+, con tile vettoriali locali e il loader sopra; si è fermato nel 2024 e non fa streaming [S29]. Utile come prova di fattibilità, non come dipendenza.
- Non ho trovato un plugin Godot 4 maturo per MVT con streaming e Android.

### 4.5 Performance mobile

- Decodifica e costruzione mesh sono **CPU-bound** e in GDScript possono essere costose su tile da centinaia di KB; vanno misurate. Il vantaggio è che il download è più piccolo per area: la tile OpenFreeMap da 620 KB copre ~3 km² (~210 KB/km²), mentre una tile raster z17 da 256 px (tipicamente 20–60 KB) copre ~0.046 km² (~430–1.300 KB/km²); il vettoriale è quindi ~2–6× più compatto per area. In memoria, 36 texture raster 256 px occupano comunque ~9 MiB.
- Il terreno vettoriale (strade, landuse) produce molti triangoli piccoli; su GPU tile-based il costo può essere alto [S3]. Per la slice non conviene renderizzare le strade come mesh: meglio raster.
- Gli edifici estrusi hanno lo stesso costo GPU dell’opzione A; il risparmio è nel network, non nel fill rate.

### 4.6 Licenze

- MVT è una specifica aperta; OpenMapTiles schema è CC-BY con attribuzione, codice BSD [S24]; Shortbread schema è CC0 [S30]; i dati restano ODbL [S19].
- OpenFreeMap: software MIT, istanza pubblica gratuita senza API key; consente download offline fino a 3.000 tile/50 MB, 4 richieste parallele, User-Agent univoco [S31][S32]. Attribuzione: OpenFreeMap, OpenMapTiles, OSM [S31].
- `vector.openstreetmap.org`: policy OSMF, niente bulk download, cache ≥7 giorni, User-Agent, niente SLA [S33].
- MapTiler/Stadia/altri provider: termini propri; vanno verificati in ticket 03/10.

### 4.7 Copertura dati

- Globale; OpenMapTiles ha altezze approssimate per tutti gli edifici; Shortbread no.
- La copertura delle altezze è comunque quella OSM: il `render_height` è una stima, non un dato verificato.
- La copertura degli edifici è quella OSM; nelle aree rurali può essere scarsa.

### 4.8 Streaming

- È il punto di forza: tile piccole, cacheabili, adatte a un client che carica solo ciò che vede; max zoom 14 significa meno tile e overzoom locale.
- Il punto debole è il decoder e la CPU; inoltre non c’è un plugin Android/Godot pronto.

---

## 5. Opzione C — SDK/plugin esistenti

### 5.1 MapLibre Native

MapLibre Native è un SDK C++ maturo, fork open di Mapbox GL Native, con supporto Android/iOS/desktop e licenza BSD-2 [S34][S35]. Supporta `fill-extrusion` (edifici estrusi) su Android dalla 5.1.0 [S36]. Sarebbe tecnicamente possibile includerlo in un’app Godot tramite un **Android plugin v2** (AAR, GDExtension/JNI) [S37], ma:

- è una **mappa 2D/2.5D con la propria camera e il proprio renderer**, non una scena 3D Godot;
- per avere l’avatar e la fisica in Godot bisognerebbe sincronizzare camera, input e trasformazioni, e portare il rendering in una texture condivisa o in overlay; non è un’integrazione da slice;
- `maplibre-native-godot` (GDExtension community) è esplicitamente **desktop-only** (Linux/Windows/macOS), usa il backend WebGPU headless e fa un **readback CPU** in una `TextureRect`; è fermo a Godot 4.3 e non supporta Android [S38]. Non è una base per il target mobile.

### 5.2 Cesium / 3D Tiles

- **3D Tiles for Godot** (Battle Road Labs) è Apache-2.0, GDExtension, supporta Windows/Linux/macOS; **Android e Web sono “coming in the future”**, richiede Forward+ e non è pensato per il renderer Mobile [S39]. Oggi non è utilizzabile sulla slice.
- **Cesium for Godot** (repo `stuarta0/godot-cesium`) è **deprecato**, WIP, target Godot 4.1 [S40]. Non è una base.
- **Cesium OSM Buildings** è un dataset 3D Tiles globale derivato da OSM: ~350 milioni di edifici, aggiornato trimestralmente, con molti attributi; richiede Cesium ion e i suoi Terms of Service, e l’attribuzione “© OpenStreetMap contributors” [S41][S42]. È un dato eccellente per un’app geospaziale, ma è **pesante, non low-poly e senza client Godot Android**: per la slice sarebbe un progetto nel progetto.

### 5.3 Mapbox e altri

Mapbox non ha un SDK Godot; MapLibre è il fork open utilizzabile. Gli SDK commerciali (Mapbox, Cesium ion) sono pensati per app native/web, non per un renderer di gioco. Integrarli in Godot significherebbe costruire un bridge e comunque non ottenere mesh di edifici controllabili dal gioco.

**Conclusione C:** nessun SDK/plugin esistente offre oggi una scena 3D low-poly integrata in Godot su Android. L’unica strada sensata con SDK sarebbe un’app a due renderer (mappa SDK + overlay Godot), che contraddice l’obiettivo “avatar 3D sulla mappa” e aumenta molto complessità e rischio.

---

## 6. Confronto sintetico

| Criterio | A: raster + Overpass | B: MVT custom/plugin | C: SDK/plugin |
|---|---|---|---|
| Qualità visiva | Alta per gli edifici (footprint OSM completi, altezze lette da OSM); terreno piatto e texture baked | Buona e nitida, ma geometria z14 overzoomed e feature fuse; Shortbread senza altezze | Alta per fotogrammetria/3D Tiles, non low-poly; integrazione con Godot assente |
| Complessità | Media-bassa: HTTP, PNG, triangolazione, estrusione | Alta: protobuf, geometria, stile, clipping, buchi | Molto alta: bridge nativo, camera, texture, licenze |
| Performance mobile | Buona se mesh unite e cache limitata; rischio memoria texture | Buona GPU, rischio CPU decode e small triangles | Dipende dall’SDK; non integrabile nel renderer Godot |
| Licenze | OSM ODbL + provider; Overpass policy | OSM ODbL + schema/provider; OpenFreeMap free | MapLibre BSD-2; Cesium ion commerciale; plugin Apache/MIT |
| Copertura dati | Globale OSM; altezze sparse | Globale; altezze OpenMapTiles | Globale, alta qualità; commerciale |
| Streaming | Tile XYZ semplice + Overpass lento/rate-limited | Tile MVT nativo, max z14 | Streaming integrato nell’SDK |
| Rischio principale | Limiti Overpass e altezze mancanti | Decoder/CPU e geometria grossolana | Nessun percorso Android/Godot pronto |

**Giudizio:** A vince per la slice perché massimizza qualità visiva e semplicità con gli strumenti già presenti in Godot, e perché il rischio principale (Overpass) è confinabile con cache e perimetro di test. B è la scelta giusta per la produzione su larga scala, ma non per la prima slice. C non è una scelta praticabile oggi.

---

## 7. Architettura raccomandata per la slice

### 7.1 Diagramma

```
GPS fix
  │
  ▼
WorldOrigin / Projection (ticket 04)
  │  lat/lon → metri locali; floating origin
  ▼
ChunkManager (griglia z17, chunk = 2×2 tile)
  ├── GroundSource (XYZ raster, provider ticket 03)
  │     └── HTTPRequest → PNG → ImageTexture → 4 quad/chunk
  ├── BuildingSource (Overpass)
  │     └── HTTPRequest → JSON → WorkerThreadPool:
  │           parse → footprint → estrusione → array mesh
  ├── CacheStore (user://map_cache, LRU, TTL)
  └── RequestScheduler (priorità, concorrenza, retry)
        │
        ▼
MeshInstance3D per chunk (1 mesh edifici + 4 quad terreno)
        │
        ▼
Camera obliqua north-up + DirectionalLight + fog
        │
        ▼
Attribution UI (© OpenStreetMap contributors + provider)
```

### 7.2 Componenti e contratti

- **`WorldOrigin`**: converte lat/lon in metri locali con una proiezione locale (ENU o Web Mercator scalato). Tutti i chunk usano la stessa origine; il rebasing periodico mantiene |x|,|z| piccoli (ticket 04). Godot consiglia di non superare ~8.192 m per un gioco 3D in terza persona senza origine mobile; oltre, usare origin shifting o coordinate grandi [S43].
- **`ChunkManager`**: chiave `z/x/y` dell’angolo NW; carica/scarica chunk in base alla distanza dal giocatore; prefetch ring 1; priorità: chunk corrente > adiacenti > resto.
- **`GroundSource`**: interfaccia `get_tile(z,x,y) -> Image/Texture`; implementazione XYZ raster. In futuro può essere sostituita da una sorgente vettoriale senza cambiare il chunk manager.
- **`BuildingSource`**: interfaccia `fetch(bbox, chunk_key) -> Array[Building]`; implementazione Overpass. `Building` contiene id, anelli esterni/interni, `height`, `min_height`, tags rilevanti.
- **`BuildingMeshBuilder`**: puro, senza accesso alla scena; produce `PackedVector3Array` vertici/normali, `PackedColorArray`, `PackedInt32Array` indici. Gira su worker.
- **`CacheStore`**: tile PNG e JSON Overpass su disco; metadata con timestamp, URL/versione, bbox; LRU su dimensione; TTL.
- **`AttributionUI`**: label persistente e link; crediti completi nel menu.

### 7.3 Regole di estrusione

1. **Preferisci `building:part` all’outline** quando esistono parti 3D: l’outline non va reso in 3D in quel caso [S9]. Se non ci sono parti, usa l’outline.
2. **Altezza**:
   - `height` numerico (gestisci “12”, “12 m”, “40 ft”); clamp 2–300 m.
   - altrimenti `building:levels × 3.0` (o 3.66 come OpenMapTiles [S25]); clamp.
   - altrimenti default 8 m (o 5 m come OpenMapTiles per gli edifici senza dati [S25]).
3. **Base**: `min_height` o `building:min_level × 3.0`; se `min_height >= height`, scarta la parte o correggi.
4. **Anelli**: scarta anelli con <3 punti, area <1 m², punti duplicati; semplifica con Douglas-Peucker (tolleranza 0.2–0.5 m) e limita a ~64 vertici per edificio.
5. **Buchi**: `Geometry2D.triangulate_polygon()` prende un solo contorno e non ha un parametro per i buchi [S8]. Per la slice: riempi i cortili (impatto visivo basso) oppure usa una triangolazione con controllo punto-in-poligono; non introdurre una libreria GIS solo per i buchi.
6. **Winding**: `Geometry2D.triangulate_polygon()` restituisce triangoli counter-clockwise [S8]; Godot usa il clockwise come front face [S11]. Inverti gli indici o costruisci le pareti con l’ordine corretto.
7. **Pareti**: per ogni lato dell’anello, due triangoli; normale orizzontale; colore per faccia (es. moltiplicatore 0.85–1.15 in base alla direzione) per il look low-poly.
8. **Tetto**: triangoli del footprint a `height`, colore leggermente più scuro; base a `min_height` se presente.
9. **Z-fighting**: base a `y = 0.05`, non coplanare con il ground; niente decal/ombre baked sul tetto.
10. **AABB**: `ArrayMesh.custom_aabb` deve includere l’intero chunk, soprattutto se un edificio sborda dal bbox [S11].

### 7.4 Materiali e luce

- **Edifici**: un `StandardMaterial3D` per chunk, `vertex_color_use_as_albedo = true`, `roughness = 1`, `metallic = 0`, `shading_mode` per-vertex se disponibile; niente texture, niente trasparenza [S12].
- **Terreno**: `StandardMaterial3D` unshaded con albedo texture, filtro lineare con mipmap; oppure shader minimale che desatura/tinta la tile per lo stile low-poly. Una texture per tile significa un materiale per tile; va bene per 4 tile/chunk. Se le draw call diventano un problema, si può compositare il 2×2 in una texture 512×512 con `Image.blit_rect` su worker e usare un solo quad per chunk, al costo di RAM e upload.
- **Luce**: una `DirectionalLight3D` senza ombre (o shadow map 512–1024 solo se il test regge), ambiente e fog lineare per nascondere il bordo dei chunk. Il renderer Mobile non ha SSAO/SSR/SDFGI [S1]; non progettare il look su quelle feature.
- **LOD**: per la slice, un solo LOD per chunk + distanza di visibilità; per il futuro, una mesh “box” semplificata per chunk lontani. Le LOD automatiche di Godot sono generate all’import, non per `ArrayMesh` runtime; per mesh runtime si possono passare LOD espliciti ad `add_surface_from_arrays()` o usare visibility range [S44][S11].
- **MultiMesh**: non serve per edifici unici; è utile per props ripetuti (alberi, lampioni) e ha il limite di non poter cullare le singole istanze [S45].

### 7.5 Streaming, cache e priorità

Proposta per la slice:

- **Zoom ground**: z17; fallback z16 mentre z17 carica. z18 solo se il provider lo offre e la memoria lo consente.
- **Tile size**: 256 px; 512 px opzionale per il ring vicino, ma il budget RAM va misurato.
- **Chunk**: 2×2 tile z17 (~430 m a latitudine italiana). È allineato alla griglia delle tile, quindi niente duplicati di terreno e cache semplice.
- **Visible set**: 3×3 chunk (9 chunk, 36 tile). Prefetch ring 1; niente prefetch di route intere.
- **Cache disco**: `user://map_cache/` con `z/x/y.png` e `overpass/{chunk}.json`; LRU 128 MB; TTL tile ≥7 giorni (o header del provider), edifici 7–30 giorni.
- **Cache RAM**: LRU texture max ~64 MB; mesh max ~32 MB; se si supera, scarica i chunk più lontani.
- **Concorrenza**: max 4 richieste HTTP (tile + Overpass) in volo; una coda con priorità; cancel delle richieste di chunk non più visibili.
- **Retry**: backoff esponenziale con jitter; su 429/406 Overpass attendi almeno 30 s [S7]; su 5xx riprova 2 volte.
- **Timeout**: tile 10 s; Overpass 30 s (query `[timeout:25]` + margine). `HTTPRequest.timeout` e `body_size_limit` (es. 8 MB) [S5].
- **User-Agent**: obbligatorio e identificabile, es. `GDGPSGame/0.1 (+contact)`; non usare il default di HTTPRequest [S22][S7].
- **Progressività**: mostra subito il ground z16/z15 (tile padre) e poi z17; gli edifici appaiono quando pronti, senza bloccare il frame.

### 7.6 Attribuzione e privacy

- Label persistente in basso: `© OpenStreetMap contributors` + nome del provider, cliccabile verso `https://www.openstreetmap.org/copyright`; crediti completi nel menu [S19][S46]. Le linee guida OSM permettono splash/credits nei giochi, ma la label sulla mappa è la soluzione più sicura [S46].
- Se si usa OpenFreeMap: aggiungi `OpenFreeMap` e `© OpenMapTiles` [S31]. Se si usa Cesium OSM Buildings: `© OpenStreetMap contributors` [S41].
- Non loggare l’URL della tile con API key; non inviare la posizione GPS a servizi non necessari; il bbox Overpass rivela l’area, quindi HTTPS e nessun analytics di terze parti.

### 7.7 Parametri e budget proposti

| Parametro | Valore proposta | Note |
|---|---|---|
| Renderer | Mobile | Già impostato [S50] |
| Ground zoom | 17 (fallback 16) | ~0.84 m/px a lat 45 |
| Tile size | 256 px | 512 px solo se misurato |
| Chunk | 2×2 tile z17 | ~430 m a lat 45 |
| Chunk visibili | 3×3 | 36 tile, ~9 MiB |
| Prefetch | ring 1 | niente prefetch di route |
| Edifici/chunk | 1 mesh | 20–30 tri/edificio |
| Draw call target | <100 | ground + edifici + avatar/HUD |
| Triangoli target | <250k | misure in ticket 09/12 |
| Texture RAM | <64 MB | runtime non compresso [S4] |
| Cache disco | 128 MB | LRU |
| FPS target | ≥30, 60 se possibile | field test ticket 12 |
| Ombre | off | directional light + vertex color |

Questi numeri sono una proposta da validare nel prototipo (ticket 09) e nei criteri di field test (ticket 12), non misure definitive.

---

## 8. Rischi e mitigazioni

| # | Rischio | Probabilità | Impatto | Mitigazione |
|---|---|---|---|---|
| 1 | Overpass pubblico lento/rate-limited/outage | Alta | Alto | Cache disco, query per chunk, limite 4 concorrenti, fallback “niente edifici”, per produzione self-host/paid o MVT/PMTiles |
| 2 | Altezze OSM mancanti/errate | Alta | Medio | Fallback `levels×3`, default 8 m, palette; non promettere accuratezza; test con edifici noti |
| 3 | Memoria texture runtime | Media | Alto | 256 px, LRU 64 MB, niente atlanti enormi, monitorare con `Performance` |
| 4 | Draw call/fill rate | Media | Medio | Mesh unite per chunk, un materiale, niente ombre/trasparenza, LOD/fog |
| 5 | Geometria invalida (self-intersection, buchi, parti) | Media | Medio | Validazione, triangulation fallback, skip, cap vertici; parti vs outline [S9] |
| 6 | Mismatch raster/Overpass (snapshot diverso) | Media | Basso | Stile ground astratto, margine, accettare; non usare roof imagery |
| 7 | Licenze/attribuzione | Bassa | Alto | Label visibile, crediti, verificare termini provider; non distribuire cache OSM senza ODbL |
| 8 | Threading (scene tree non thread-safe) | Media | Alto | Worker solo dati; main thread per texture/mesh; mutex; `call_deferred` [S18] |
| 9 | Precisione coordinate/floating origin | Media | Medio | Ticket 04; origin shifting; non superare ~8 km senza rebasing [S43] |
| 10 | Plugin abbandonato (B/C) | Alta se scelto | Alto | Non usare plugin non mantenuti nella slice; isolare dietro interfacce |
| 11 | API key estratta dall’APK | Media | Medio | Restrizioni provider, rotazione, niente key nei log; ticket 03 |
| 12 | Cache/offline non consentiti | Media | Alto | Usare provider che consentano caching; rispettare policy OSM; niente bulk |

---

## 9. Percorso di evoluzione

1. **Slice (adesso):** opzione A, un quartiere, 1 km di percorso, z17, chunk 2×2, Overpass con cache. Obiettivo: validare look, scala, performance e UX su Fairphone.
2. **Produzione iniziale:** precalcola gli edifici dell’area di gioco con Planetiler/OpenMapTiles o un profilo custom a partire da un extract Geofabrik [S48], esporta in **PMTiles** e servi da storage statico; il client legge MVT/PMTiles e non interroga Overpass a runtime [S27][S47]. PMTiles è un archivio single-file su storage statico, adatto a range request e cache [S47].
3. **Scala:** se serve terreno vettoriale, etichette, POI o aggiornamenti frequenti, passa a un renderer MVT completo (custom o SDK) e a tile self-hosted; valuta 3D Tiles solo se il target diventa fotogrammetrico, non low-poly.

Trigger per passare da A a B/PMTiles:

- più di ~100 query Overpass/giorno o p95 > 2–3 s;
- necessità di funzionare offline o con molti utenti;
- necessità di terreno vettoriale/etichette o di altezze più affidabili;
- il prototipo visivo mostra che la grossolanità z14 è accettabile (allora MVT è competitivo).

---

## 10. Handoff agli altri ticket

- **03 (provider tile):** scegliere un provider che consenta streaming/caching in app, stile senza etichette o minimale, 256/512 px, attribuzione; verificare i termini su cache e uso commerciale. `tile.openstreetmap.org` solo in sviluppo, mai in release [S22].
- **04 (coordinate):** definire proiezione locale, origine, rebasing e allineamento tra tile raster e footprint Overpass; usare la stessa origine per ground e buildings.
- **09 (prototipo visivo):** costruire 3×3 chunk con ground z17 + edifici Overpass; misurare draw call, triangoli, memoria, tempo di caricamento; decidere palette, altezze di fallback e LOD.
- **10 (streaming/cache):** finalizzare chunk size, prefetch, TTL, LRU, coda e retry; usare i numeri di questa ricerca come punto di partenza.
- **12 (field test):** definire FPS minimo, tempo massimo di comparsa edifici, memoria massima, comportamento con GPS impreciso e zone senza edifici.

---

## 11. Fonti

Tutte le fonti sono state consultate il 2026-10-31. Le URL puntano alla versione corrente; per documenti mutevoli (policy, wiki) la data di consultazione è indicata.

| ID | Fonte | URL |
|---|---|---|
| S1 | Godot 4.7 — Overview of renderers | https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html |
| S2 | Godot 4.7 — Optimizing 3D performance (instancing, LOD, large worlds) | https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html |
| S3 | Godot 4.7 — GPU optimization (mobile/tile renderers, overdraw, shadows) | https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html |
| S4 | Godot 4.7 — `Image` (runtime compression only in editor) | https://docs.godotengine.org/en/stable/classes/class_image.html |
| S5 | Godot 4.7 — `HTTPRequest` | https://docs.godotengine.org/en/stable/classes/class_httprequest.html |
| S6 | Godot 4.7 — `ImageTexture` | https://docs.godotengine.org/en/stable/classes/class_imagetexture.html |
| S7 | OSM Wiki — Overpass API (public instances, limits, 429/406) | https://wiki.openstreetmap.org/wiki/Overpass_API |
| S8 | Godot 4.7 — `Geometry2D` (`triangulate_polygon`) | https://docs.godotengine.org/en/stable/classes/class_geometry2d.html |
| S9 | OSM Wiki — Simple 3D Buildings | https://wiki.openstreetmap.org/wiki/Simple_3D_buildings |
| S10 | OSM Wiki — Buildings (outline variability, courtyards) | https://wiki.openstreetmap.org/wiki/Buildings |
| S11 | Godot 4.7 — `ArrayMesh` (winding, custom AABB, LOD) | https://docs.godotengine.org/en/stable/classes/class_arraymesh.html |
| S12 | Godot 4.7 — `BaseMaterial3D` (`vertex_color_use_as_albedo`) | https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html |
| S13 | taginfo — key `building` (2026-10-31) | https://taginfo.openstreetmap.org/api/4/key/stats?key=building |
| S14 | taginfo — keys `height`, `building:levels`, `building:part` (2026-10-31) | https://taginfo.openstreetmap.org/api/4/key/stats?key=height · https://taginfo.openstreetmap.org/api/4/key/stats?key=building%3Alevels · https://taginfo.openstreetmap.org/api/4/key/stats?key=building%3Apart |
| S15 | OSM Wiki — Buildings (group outlines, detailed outlines) | https://wiki.openstreetmap.org/wiki/Buildings |
| S16 | Godot 4.7 — `WorkerThreadPool` | https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html |
| S17 | Godot 4.7 — Thread-safe APIs | https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html |
| S18 | Godot 4.7 — Thread-safe APIs (scene tree, GPU upload) | https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html |
| S19 | OpenStreetMap — Copyright and License | https://www.openstreetmap.org/copyright |
| S20 | Open Data Commons — ODbL 1.0 | https://opendatacommons.org/licenses/odbl/1-0/ |
| S21 | OSMF — Attribution Guidelines | https://osmfoundation.org/wiki/Licence/Attribution_Guidelines |
| S22 | OSMF — Tile Usage Policy (raster) | https://operations.osmfoundation.org/policies/tiles/ |
| S23 | Mapbox Vector Tile Specification 2.1 | https://github.com/mapbox/vector-tile-spec/blob/master/2.1/README.md |
| S24 | OpenMapTiles — Schema | https://openmaptiles.org/schema/ |
| S25 | OpenMapTiles — `building.sql` (height fallback 3.66/5 m) | https://github.com/openmaptiles/openmaptiles/blob/master/layers/building/building.sql |
| S26 | Shortbread — Vector Tile Schema 1.1 | https://shortbread-tiles.org/schema/1.1/ |
| S27 | Planetiler — README (merge, PMTiles, OpenMapTiles) | https://github.com/onthegomap/planetiler |
| S28 | `godot-geo-tile-loader` (Rust/GDScript MVT loader, 2023) | https://github.com/pka/godot-geo-tile-loader |
| S29 | `3D-OSM-GODOT` (Godot 4.1, local vector tiles) | https://github.com/Frataj/3D-OSM-GODOT |
| S30 | Shortbread — Copyright & License (CC0 schema) | https://shortbread-tiles.org/copyright/ |
| S31 | OpenFreeMap — public instance and attribution | https://openfreemap.org/ |
| S32 | OpenFreeMap — Terms of Service (offline limits) | https://openfreemap.org/tos/ |
| S33 | OSMF — Vector Tile Usage Policy | https://operations.osmfoundation.org/policies/vector/ |
| S34 | MapLibre Native — README (Android/iOS, BSD-2) | https://github.com/maplibre/maplibre-native |
| S35 | MapLibre Native — LICENSE | https://github.com/maplibre/maplibre-native/blob/main/LICENSE.md |
| S36 | MapLibre Style Spec — `fill-extrusion` (Android support) | https://maplibre.org/maplibre-style-spec/layers/#fill-extrusion |
| S37 | Godot 4.7 — Android plugins (v2, AAR, GDExtension) | https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html |
| S38 | `maplibre-native-godot` — README (desktop-only, CPU readback) | https://github.com/yuiseki/maplibre-native-godot |
| S39 | 3D Tiles for Godot — README (platforms, Forward+) | https://github.com/Battle-Road-Labs/3D-Tiles-For-Godot |
| S40 | Cesium for Godot — README (deprecated, WIP 4.1) | https://github.com/stuarta0/godot-cesium |
| S41 | Cesium OSM Buildings — data, coverage, attribution | https://cesium.com/platform/cesium-ion/content/cesium-osm-buildings/ |
| S42 | Cesium — Global 3D Content Terms | https://cesium.com/legal/cesium-global-3d-content-tos/ |
| S43 | Godot 4.7 — Large world coordinates (precision, origin shifting) | https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html |
| S44 | Godot 4.7 — Mesh level of detail (LOD) | https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html |
| S45 | Godot 4.7 — Optimization using MultiMeshes | https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html |
| S46 | OSMF — Attribution Guidelines (computer games) | https://osmfoundation.org/wiki/Licence/Attribution_Guidelines |
| S47 | PMTiles — single-file archive, static storage, license | https://github.com/protomaps/PMTiles |
| S48 | Geofabrik — OSM extracts (ODbL) | https://download.geofabrik.de/ |
| S49 | OSM Wiki — Slippy map tilenames (tile formulas, 256 px) | https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames |
| S50 | Progetto locale — `project.godot` (Godot 4.7, Mobile) | `project.godot` |
| S51 | Progetto locale — `.scratch/gps-game/map.md` (scope e target) | `.scratch/gps-game/map.md` |

---

## Appendice A — Misure locali del 2026-10-31

### A.1 Overpass, bbox Milano centro

Query:

```
[out:json][timeout:25];
way["building"](45.4635,9.1880,45.4655,9.1910);
out geom;
```

Risultato: HTTP 200, **15.797 byte**, **29,07 s**, **14 elementi** (`way`), 3 con `height`, 11 con `building:levels`, 0 `building:part`; `osm_base` 2026-10-31T21:20:06Z.

URL: `https://overpass-api.de/api/interpreter` (POST). La latenza è dominata dal carico del server; non usare questo numero come stima di throughput.

### A.2 OpenFreeMap, tile z14 Milano

URL: `https://tiles.openfreemap.org/planet/20261025_080012_pt/14/8610/5863.pbf`

Risultato: HTTP 200, **620.352 byte**, layer `building`: **67 feature**, **2.959 anelli** totali, una feature con **1.414 anelli**; tutte le 67 feature avevano `render_height` e `render_min_height`; 34 avevano `colour`. Il tile copre ~1.7 km di lato a latitudine 45 (~3 km²). Il tilejson del servizio dichiara `maxzoom: 14` e layer `building` da z13 a z14 [S31].

### A.3 Shortbread OSMF, tile z14 Milano

URL: `https://vector.openstreetmap.org/shortbread_v1/14/8610/5863.mvt`

Risultato: HTTP 200, **424.265 byte**, layer `buildings`: **una sola feature**, **62.071 interi di geometria**, **nessun attributo**. Lo schema Shortbread documenta solo `dummy` per il layer buildings [S26]. Non è utilizzabile per altezze o stile per edificio.

### A.4 Calcoli di risoluzione

Formula Web Mercator: `meters_per_pixel = 40075016.686 × cos(lat) / 2^zoom / tile_size` (tile_size 256) [S49].

- z14, lat 45.464°: ~6.7 m/px; tile 256 px ~1.7 km.
- z17, lat 45.464°: ~0.84 m/px; tile 256 px ~215 m.
- Un edificio di 20 m: ~3 px a z14, ~24 px a z17.

Questi calcoli spiegano perché i footprint Overpass a piena risoluzione siano visivamente superiori a un MVT z14 overzoomed per l’edificato di prossimità.

---

## Appendice B — Query Overpass consigliata per la slice

```
[out:json][timeout:25];
(
  way["building"](bbox);
  way["building:part"](bbox);
  relation["building"](bbox);
);
out geom;
```

Note:

- `bbox` è `south,west,north,east` (ordine Overpass QL) [S7].
- `out geom` restituisce la geometria inline; per le relation verificare in overpass turbo che i membri abbiano geometria, altrimenti usare una query con ricorsione (`out body; >; out geom;`) o gestire i membri separatamente.
- Aggiungere un margine di ~20 m al bbox del chunk per gli edifici a cavallo; assegnare l’edificio al chunk del centroide e impostare `custom_aabb` per evitare culling errato.
- Non usare `out meta` nella slice: aumenta il payload senza servire al rendering.
- Su 429/406 attendere almeno 30 s; non lanciare query parallele [S7].
