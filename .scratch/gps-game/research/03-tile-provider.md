# Provider tile OSM per la slice — ricerca e decisione

- **Ticket:** `.scratch/gps-game/issues/03-tile-provider.md`
- **Data:** 31 ottobre 2026
- **Tipo:** research su fonti primarie (pricing, termini, API docs, policy OSMF)
- **Esito:** **MapTiler Cloud Free + stile custom pubblicato come raster XYZ**; `tile.openstreetmap.org` solo in sviluppo desktop, mai nell'APK.

## TL;DR

La slice ha bisogno di tile raster XYZ da mettere sotto gli edifici 3D, con un look flat/low-poly, retina su Android e una quota free sufficiente per un singolo tester. Dei tre provider commerciali, **solo MapTiler consente di creare e pubblicare uno stile raster custom nel piano Free** (5 stili, Map Designer), e lo fa con una API key mobile restringibile via `User-Agent`. È la scelta primaria.

Il costo è un piano Free **non commerciale / R&D**, con **logo MapTiler obbligatorio**, **100.000 richieste API/mese** e conteggio **4 richieste per tile 512 px `@2x`** (quindi ~25.000 tile retina/mese). Per la slice è sufficiente; per volume o uso commerciale si passa a Flex ($30/mese, 500k richieste) o si rivaluta Thunderforest/Stadia.

`tile.openstreetmap.org` non è un'alternativa di produzione: policy OSMF vieta prefetch/offline, non ha SLA e può bloccare l'accesso senza preavviso. Va usato solo come comodità di sviluppo desktop, senza prefetch e con `User-Agent` identificabile.

---

## 1. Requisiti e criteri

Dalla mappa di progetto e dal ticket:

1. **Free tier** utilizzabile per una vertical slice non commerciale.
2. **API key per app mobile Android**, senza committarla nel repository.
3. **Stile personalizzabile / low-poly**: palette flat, pochi label, colori controllabili.
4. **Tile retina** (`@2x`) per schermo Android ad alta densità.
5. **Quota** compatibile con streaming e cache durante i field test.
6. **Termini d'uso** compatibili con un'app distribuita via APK (non store) e con cache on-device.
7. **Attribuzione OSM visibile** e conforme a ODbL/OSMF, più attribuzione del provider.
8. **Nessun backend** nella slice: la key mobile sarà estraibile dall'APK; servono mitigazioni, non segretezza assoluta.

---

## 2. Metodo e perimetro

Sono state consultate solo fonti primarie: pagine prezzi ufficiali, termini di servizio, documentazione API, policy della OpenStreetMap Foundation e pagine copyright. Le citazioni sono riportate in lingua originale; il resto del report è in italiano. Tutte le URL sono elencate in fondo e sono state consultate il **31 ottobre 2026**.

Non è stata fatta una prova di acquisto/account: i limiti sono quelli pubblicati. Prima di implementare, verificare nel dashboard del provider che la quota e le funzioni del piano corrispondano a quanto documentato.

---

## 3. Confronto sintetico

| Criterio | MapTiler Free | Thunderforest Hobby | Stadia Maps Free | `tile.openstreetmap.org` |
|---|---|---|---|---|
| Prezzo | $0 | $0 | $0 | $0 (donazioni) |
| Quota free | 100.000 richieste API/mese | 150.000 tile requests/mese | 200.000 crediti/mese | best-effort, nessuna quota/SLA |
| Costo retina | tile 512 px `@2x` = **4 richieste** → ~25.000 tile/mese | `@2x` = 1 richiesta; nessun moltiplicatore documentato | 512 px = 1 credito; nessun moltiplicatore documentato | nessun `@2x` documentato |
| Stile custom free | **sì, 5 stili** con Map Designer | no; custom cartography a pagamento | no raster; vector custom con MapLibre; raster custom su preventivo | no |
| Stile “low-poly” pronto | no, ma personalizzabile | no; Atlas/Atlas Canvas sono i più neutri | no; Alidade Smooth è il più adatto | no |
| API key mobile | sì, restringibile per `User-Agent` | sì; 1 key nel free | sì; key per mobile | nessuna key; serve `User-Agent` |
| Cache on-device | sì, cache personale del singolo utente | sì, anche offline | sì, max 100 MB e 7 giorni/header | sì, min 7 giorni; no offline |
| Uso commerciale free | no (R&D sì) | consentito dai termini; free discrezionale | no | non appropriato |
| Attribuzione | MapTiler + OSM + **logo** | Thunderforest + OSM | Stadia + OpenMapTiles + OSM | OSM |
| Quota esaurita | servizio in pausa fino al mese successivo | throttle/upgrade | HTTP 429 fino al ciclo successivo | blocco senza preavviso |
| Verdetto per la slice | **primario** | fallback per volume/commerciale | fallback se il logo è bloccante | solo sviluppo desktop |

---

## 4. MapTiler Cloud Free

### 4.1 Quota e conteggio

La pagina prezzi indica per il piano Free:

> “Suitable for testing, PoC, prototyping, personal, or non-commercial use.”  
> “Vector & XYZ raster tiles”  
> “MapTiler logo on the map” [1]

e nella tabella “Included in plans”:

> “API keys 1”  
> “Custom map styles 5”  
> “API requests 100k/month” [1]

Il conteggio è per **richiesta API**, non per “sessione”, perché useremo HTTP diretto da Godot e non l’SDK JS:

> “If you built your map app using MapTiler API combined with 3rd party clients and libraries, then the traffic is tracked by request.” [6]

La tabella di conteggio è esplicita:

> “Rendered raster 512x512px tile including HiDPI/Retina — 4 per tile”  
> “Rendered raster 256x256px tile including HiDPI/Retina — 1 per tile” [6]

Quindi **100.000 richieste/mese = 25.000 tile 512 px `@2x`**, oppure 100.000 tile 256 px. È il punto più importante da mettere nel budget: il retina costa 4×.

A quota esaurita:

> “On a FREE plan service will pause until the next month without an upgrade to paid plans.” [1]

Nessun overage billing sul free: adatto a un prototipo, ma il gioco deve gestire la pausa con tile in cache o placeholder, non con un fallback silenzioso a OSM.

### 4.2 Stile e low-poly

MapTiler è l’unico dei tre con uno **stile raster custom self-service nel free tier**: 5 stili inclusi [1]. Il flusso è:

1. duplicare uno stile base (es. `dataviz-v4`) in Map Designer;
2. cambiare fill/outline/opacity per layer, con styling anche per intervallo di zoom [10][11];
3. nascondere i layer che non servono (POI, numeri civici, trasporti, hillshade, edifici 3D);
4. pubblicare: lo stile diventa un `mapId` usabile via Maps API, anche in app mobile [7];
5. usare il `mapId` nell’endpoint raster XYZ [5].

Il punto chiave: **“low-poly” non è uno stile venduto da nessun provider**. È un obiettivo visivo che si ottiene con palette flat, pochi label e geometrie 3D separate. MapTiler consente di avvicinarsi molto, perché il colore è “cotto” lato server; non serve un renderer vector in Godot e non si “modifica” il tile a runtime.

La guida “Publish a custom map” conferma che dopo la pubblicazione lo stile è utilizzabile “in mobile app, via WMTS service, in a GIS app” [7]. La Maps API espone il raster XYZ per `mapId` [5]. Verifica di implementazione: con una richiesta reale al `mapId` custom, controllare che il piano Free restituisca il raster `@2x`; la documentazione lo supporta (custom styles + XYZ raster), ma è un punto da validare nel dashboard prima di costruire la pipeline.

### 4.3 Retina e URL

La Maps API ha un endpoint raster XYZ:

```
GET https://api.maptiler.com/maps/{mapId}/{tileSize}/{z}/{x}/{y}{scale}.{format}?key=...
```

Con:

- `tileSize` = `256`;
- `scale` = `@2x` per retina/HiDPI;
- `format` = `png` (o `jpg`, `webp`).

La documentazione dice:

> “Use `@2x` to get ‘retina’/HiDPI image.” [5]

Esempio ufficiale:

```
https://api.maptiler.com/maps/streets-v4/256/1/1/1@2x.png?key=YOUR_MAPTILER_API_KEY
```

Quindi per lo stile custom:

```
https://api.maptiler.com/maps/{MAP_ID}/256/{z}/{x}/{y}@2x.png?key={KEY}
```

Il `@2x` restituisce un’immagine 512×512 ma viene conteggiato come 4 richieste [1][6]. Per risparmiare quota: 256 px sotto z15, `@2x` da z15 in su (dove i label e i bordi si vedono davvero).

### 4.4 API key per app mobile

MapTiler documenta esplicitamente il caso “native applications”:

> “For native applications, secure the key with **Allowed User-Agent header**: Enter a substring unique to your app’s User-Agent. Only requests carrying a matching User-Agent are processed.” [4]

> “The match is case-sensitive and only needs to be a substring, so keep it unique to your app to avoid accidentally matching someone else’s User-Agent.” [4]

Quindi la key può essere limitata a un `User-Agent` tipo `GDGPSGame/0.1 ...`. Non è una difesa crittografica (l’header è falsificabile e la key è nell’APK), ma alza il costo di un abuso ingenuo e permette di identificare il traffico. MapTiler consiglia anche rotazione periodica:

> “Rotate keys periodically … A typical setup is 2–3 months.” [4]

> “On a free plan, your maps might get suspended for the rest of the billing period.” [4]

La key va comunque trattata come **non committabile** (vedi §8.5).

### 4.5 Termini, cache e attribuzione

**Uso del piano Free.** I termini Cloud sono espliciti:

> “Usage of the Free Plan is limited to non-commercial use and research & development for commercial products applications.” [2]

La slice è esattamente R&D/non commerciale: ok. Se un giorno l’app diventa commerciale, serve Flex o Custom, non il Free.

**Cache.** È consentita la cache locale del singolo utente:

> “Results of requests can be stored in a temporary personal cache (browser cache, mobile app cache, etc.) for use by a single end-user only.” [2]

Sono invece vietati proxy e cache server-side:

> “It is prohibited to store, save, and/or redistribute any map content from a server-side cache or temporary storage or by using a screenshot or other static image, instead of directly accessing via our APIs.” [2]

e il bulk download:

> “It is prohibited to batch or excessive bulk download of map tiles or otherwise use the Service beyond the limits of these Terms.” [2]

Quindi: cache su dispositivo sì; prefetch massiccio, download di quartieri, cache condivisa o proxy no. Il prefetch “a anello” intorno al giocatore deve restare modesto e legato alla vista corrente, non diventare un “download area”.

**Modifica dei tile.** I termini generali vietano di manipolare il contenuto:

> “It is expressly prohibited to manipulate or modify map content, in the form of vectors, pixels or underlying metadata.” [3]

Questo è un motivo in più per ottenere il look low-poly **nello stile MapTiler pubblicato**, non con un shader che ricolora il tile a runtime.

**Attribuzione.** I termini generali richiedono:

> “When using Map Content, the Customer is required to add ‘© MapTiler’ (with Free Account the MapTiler logo) when displaying maps. This should hyperlink to https://www.maptiler.com/copyright/.” [3]

> “If the Map Data being used is based on OpenStreetMap data, the Customer is required to add ‘© OpenStreetMap’ when displaying maps. This should hyperlink to: https://www.openstreetmap.org/copyright.” [3]

La guida attribuzione precisa:

> “The text attribution must appear on every map. It includes copyright notices with links for MapTiler and also for OpenStreetMap…”  
> “If you’re using a MapTiler Free account, you also need to display the MapTiler logo linking to our website.” [8]

Testo consigliato:

```
© MapTiler    © OpenStreetMap contributors
```

con link a `https://www.maptiler.com/copyright/` e `https://www.openstreetmap.org/copyright`, più il logo MapTiler (free) che linka `https://www.maptiler.com/`. La guida dice che per “Maps in videos, games, or animations” si può mettere l’attribuzione “overlay in a corner or include in credits” [8]. I dati OSM sono ODbL e la pagina copyright di MapTiler ricorda l’attribuzione minima [9]. Su mobile i termini consentono anche un popup per l’attribuzione [3]; per evitare ambiguità sul logo, la soluzione più sicura resta una barra persistente piccola + schermata “Licenze”.

### 4.6 Verdetto MapTiler

**Pro:**

- unico free con stile raster custom self-service (5 stili);
- Map Designer permette palette flat, hiding dei layer, styling per zoom;
- endpoint raster XYZ con `@2x`;
- key mobile con restrizione `User-Agent`;
- free per R&D/non commerciale;
- quota 100k richieste (~25k retina) sufficiente per la slice;
- a quota esaurita si ferma, non fattura.

**Contro:**

- logo MapTiler obbligatorio nel free;
- retina 4× come costo;
- 1 sola API key nel free (niente separazione dev/prod);
- stile custom vive nel cloud MapTiler (map ID), non è un file locale;
- free non commerciale: se la slice diventa prodotto, va cambiato piano.

---

## 5. Thunderforest Hobby

### 5.1 Quota, key e retina

Pricing:

> “Hobby Project — 150,000 tile requests per month — Free” [12]

> “We count individual HTTP requests to our API. For example, with our Map Tiles API each time you request an map tile image, that counts as a request.” [12]

API key:

> “As standard, we provide you with one API Key. You can request multiple API Keys if you are on a paid plan.” [14]

> “You can ask us at any time to rotate your API Key.” [14]

Retina:

> “The `scale` parameter allows you to request ‘retina’ or ‘hidpi’ map images. For example, setting the scale to `@2x` will return map tiles at double scale…” [15]

URL:

```
https://api.thunderforest.com/{style}/{z}/{x}/{y}{scale}.{format}?apikey={apikey}
```

Non è documentato un moltiplicatore per `@2x`: la pagina prezzi definisce una richiesta come una richiesta HTTP di un’immagine tile [12]. Quindi, in via prudenziale, **150k tile `@2x`/mese** è la stima di lavoro, ma va verificata nel dashboard.

### 5.2 Stile

Thunderforest ha stili pronti (OpenCycleMap, Transport, Landscape, Outdoors, Atlas, Transport Dark, Atlas Canvas, ecc.) [28]. Non c’è uno stile “low-poly” e non c’è un editor self-service: la custom cartography è un servizio a pagamento:

> “Our custom maps have an initial design and setup charge of $245.”  
> “We charge an ongoing maintenance fee of $55 per month for your custom style…” [16]

I termini permettono di testare l’integrazione con gli stili esistenti sul free plan [16]. Per la slice, si potrebbe usare **Atlas** o **Atlas Canvas** e accettare un look più cartografico, oppure fare un tint lato client — ma il tint non è la stessa cosa di uno stile low-poly e può entrare in conflitto con i termini/licenza.

### 5.3 Termini, cache, attribuzione

> “Commercial use is permitted and encouraged.” [13]

> “All individual map images are provided under a Creative Commons licence, specifically CC-BY-SA 4.0.” [13]

> “Tiles may be cached in-browser and on-device for offline use.”  
> “Apps may retain tiles beyond the HTTP Expiry date, until fresh tiles are downloaded.” [13]

> “Caching proxies or other redistribution methods are not permitted.” [13]

> “Your application must provide honest HTTP Referer and/or User-Agent headers.” [13]

Bulk download:

> “Absolutely no bulk-downloading scraping, pre-downloading, pre-caching or anything similar without an appropriate plan.”  
> “If you wish to make bulk downloads, please upgrade your account to the Small Business plan or higher.” [13]

Attribuzione:

> “Attribution must be given to both ‘Thunderforest’ and ‘OpenStreetMap contributors’.”  
> “Users of your site/application must have a working links to www.thunderforest.com and www.openstreetmap.org/copyright” [13]

Testo:

```
Maps © Thunderforest, Data © OpenStreetMap contributors
```

Quota esaurita/traffico:

> “We won’t charge you for a short-term traffic surge — instead, we can temporarily throttle traffic to avoid you going over your quota.” [13]

Il free plan è discrezionale:

> “We offer a free plan at our discretion.”  
> “We reserve the right to modify or withdraw the free plan.” [13]

### 5.4 Verdetto Thunderforest

**Pro:**

- 150k tile/mese; se `@2x` conta 1, è più generoso di MapTiler sul retina (ma meno di Stadia);
- uso commerciale consentito dai termini;
- cache on-device/offline esplicitamente ammessa;
- niente logo;
- key semplice, rotazione via supporto.

**Contro:**

- nessuno stile custom self-service; custom a $245 + $55/mese;
- stili esistenti non low-poly;
- una sola key nel free;
- free plan discrezionale e senza garanzia;
- per il nostro look servirebbe un compromesso visivo o un costo aggiuntivo.

**Ruolo:** fallback per volume/commerciale se il look custom non è più un requisito, o se MapTiler Free diventa stretto.

---

## 6. Stadia Maps Free

### 6.1 Quota, crediti e retina

Pricing:

> “Free — $0/month — 200,000 credits/month”  
> “Standard basemaps”  
> “Basic APIs only”  
> “Commercial use not allowed” [17]

> “Standard Raster Basemaps — 1/tile” [17]

> “All new accounts receive a no-obligation 14-day trial of Stadia Maps Professional… Your account will remain on our free plan after your trial unless you decide to upgrade.” [17]

Raster:

> “All of our house styles are available as PNG raster tiles in 256x256 px and 512x512 px ‘retina’ sizes.” [20]

URL:

```
https://tiles.stadiamaps.com/tiles/<style>/{z}/{x}/{y}{r}.png
https://tiles.stadiamaps.com/tiles/<style>/{z}/{x}/{y}@2x.png
```

La pagina prezzi non distingue 256/512 nel costo: 1 credito per tile raster standard [17]. Quindi 200k crediti = ~200k tile, retina incluso secondo la documentazione disponibile; da confermare in dashboard.

### 6.2 Stile

Stadia ha stili molto curati (Alidade Smooth, Alidade Smooth Dark, Alidade Bright, Outdoors, Stamen Toner/Terrain/Watercolor, OSM Bright) [27]. **Alidade Smooth** è il più vicino a una base muta per il low-poly: “muted color scheme and fewer points of interest” [27]. Per le app mobile Stadia documenta esplicitamente l’uso di una API key [19].

Ma per il raster custom:

> “If you are still sure that you need raster tiles for your custom style, contact us for a quote.” [21]

Gli stili custom vector sono possibili con MapLibre/Maputnik [21], ma il nostro rendering Godot è raster XYZ: senza un renderer vector, il custom raster Stadia richiede un preventivo e non è self-service.

### 6.3 Termini, cache, attribuzione

Free tier:

> “Our free tier is available for development, evaluation, and non-commercial use (including academic use). Other uses require a paid subscription.” [18]

> “Our free tier may only be used for non-commercial or evaluation purposes…” [22]

Quota esaurita:

> “After you use all of your credits for a billing period … our default action is to hard limit until the start of the next billing cycle or plan upgrade (all APIs will respond with HTTP 429 Rate Limit Exceeded).” [18]

Cache on-device:

> “bulk downloading of data, except for the purpose of caching small amounts of data for offline use in a mobile application, not to exceed 100MB cached at a time per device” [22]

> “standard client-side caching (server-side caching is prohibited) for performance reasons provided that the cache is local to the client device and the data is not retained for longer than the HTTP caching headers, or 7 days in the case that a header is not returned” [22]

Attribuzione:

> “© Stadia Maps © OpenMapTiles © OpenStreetMap” [23]

con link a `https://stadiamaps.com/attribution/`, `https://openmaptiles.org/`, `https://www.openstreetmap.org/copyright` [23].

### 6.4 Verdetto Stadia

**Pro:**

- 200k crediti/mese, il più alto dei tre;
- niente logo, solo testo;
- Alidade Smooth è già una buona base muta;
- key mobile supportata;
- hard limit a 429, nessuna fattura a sorpresa.

**Contro:**

- custom raster solo su preventivo;
- free non commerciale;
- cache on-device limitata a 100 MB e 7 giorni/header;
- key non restringibile per app (nessuna allowlist documentata);
- stile custom vector non utilizzabile dal nostro pipeline raster.

**Ruolo:** fallback se il logo MapTiler è inaccettabile e Alidade Smooth basta; o se si passa a vector tile/MapLibre.

---

## 7. `tile.openstreetmap.org` — solo sviluppo

La policy OSMF è chiara:

> “OpenStreetMap (OSM) data is free for everyone to use. Our tile servers are not…”  
> “Availability is best-effort: there is no SLA or guarantee.” [24]

Obblighi:

> “Use the correct URL: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`.”  
> “Provide visible licence attribution…”  
> “Send a valid HTTP User-Agent that clearly identifies your application…”  
> “Cache tiles locally according to HTTP caching headers (or at least 7 days if your cache cannot read them).” [24]

Divieti:

> “Bulk download (‘scrape’) tiles or offer prefetch features.”  
> “Offline use is not permitted on `tile.openstreetmap.org`.” [24]

> “Commercial services, or those that seek donations, should be especially aware that access may be withdrawn at any point: you may no longer be able to serve your paying customers if access is withdrawn.” [24]

> “Apps must configure a distinct, stable `User-Agent` naming your app and optionally include a contact URL or email.” [24]

> “Do not hide attribution beneath UI, behind toggles, or off-screen.” [24]

La URL documentata non ha variante `@2x`: niente retina documentata. Quindi OSM standard è inadatto anche solo visivamente per uno schermo Android moderno.

**Uso ammesso nella slice:** solo desktop/dev, con fake GPS, viewport interattivo, nessun prefetch, cache 7 giorni, `User-Agent` tipo `GDGPSGame-dev/0.1 (+https://example.org; contact: ...)`, attribuzione `© OpenStreetMap contributors` con link a `https://www.openstreetmap.org/copyright` [25]. **Mai nell’APK distribuito via WhatsApp**, nemmeno come fallback automatico. Se il client fa streaming/prefetch (cosa probabile nella slice), OSM standard va escluso anche in dev e si usa la key MapTiler di sviluppo.

In pratica: `tile.openstreetmap.org` è utile per un primo “vedo qualcosa” senza account, non come piano B di produzione. La policy stessa rimanda a provider OSM-derived o self-hosting [24].

---

## 8. Decisione raccomandata

### 8.1 Scelta

**MapTiler Cloud Free + stile custom “low-poly” pubblicato come raster XYZ.**

Motivazione sintetica:

1. **Stile:** è l’unico dei tre con editor e 5 stili custom inclusi nel free; possiamo ottenere la palette flat e nascondere i layer che rovinano il look.
2. **Mobile:** la key è pensata per app native e si può restringere per `User-Agent`.
3. **Retina:** endpoint `@2x` documentato.
4. **Quota:** 100k richieste/mese, ~25k tile retina; sufficiente per un tester con cache.
5. **Termini:** free per R&D/non commerciale, esattamente il perimetro della slice; la cache on-device è ammessa.
6. **Attribuzione:** testo + logo, link OSM; gestibile con una barra e una schermata licenze.

### 8.2 Cosa significa “low-poly” qui

Nessun provider vende tile “low-poly”. Il look si costruisce in tre strati:

1. **Tile raster**: palette piatta, pochi label, niente hillshade/POI/edifici 3D cotti nel raster.
2. **Edifici 3D**: estrusione dei footprint OSM (ticket 02) con colori flat e lighting semplice.
3. **Post-processing/UI**: nebbia, ombre leggere, HUD minimale; **non** ricolorare il tile a runtime (i termini MapTiler lo vietano [3]).

Per questo lo stile custom MapTiler è la parte che sblocca il resto: se il tile è già “pulito”, il low-poly si ottiene con geometria e palette, non con effetti sul raster.

### 8.3 Configurazione consigliata

Config committed (nessun segreto):

```ini
# config/tiles.cfg  (committed)
[provider]
name = "maptiler"
map_id = "<map-id-dello-stile-custom>"
base_url = "https://api.maptiler.com/maps/{map_id}/256/{z}/{x}/{y}{scale}.png"
max_zoom = 20
attribution = "© MapTiler © OpenStreetMap contributors"
```

Segreto locale (ignorato):

```ini
# secrets.cfg  (NON committare)
[maptiler]
api_key = "..."
```

Template committed:

```ini
# secrets.example.cfg  (committed, vuoto)
[maptiler]
api_key = ""
```

URL runtime:

```text
https://api.maptiler.com/maps/{MAP_ID}/256/{z}/{x}/{y}@2x.png?key={API_KEY}
```

- `@2x` solo da z15 in su; sotto z15 usare 256 px per risparmiare quota.
- `max_zoom` 20 prudenziale: oltre, upscale dell’ultimo tile disponibile.
- Header `User-Agent` su **ogni** richiesta: `GDGPSGame/0.1 (+https://example.org; contact: maps@example.org)`.
- Non loggare mai l’URL completo: contiene `key`. Loggare solo `map_id`, `z/x/y`, `scale`.

### 8.4 Ricetta per lo stile custom

Procedura consigliata in MapTiler Map Designer:

1. Duplicare `dataviz-v4`.
2. Palette di esempio (da adattare al gioco):
   - background/land: `#F2E8D5`
   - water: `#8FCFD1`
   - park/landcover: `#DDE6C8`
   - roads: `#FFFFFF`, casing `#E6D8C6`
   - boundaries: `#B8A99A`
3. Nascondere: POI, numeri civici, trasporti, contour lines, hillshade, edifici 3D.
4. Tenere: acqua, landcover, strade principali/secondarie, confini, pochi label di località (massimo z12–13).
5. Styling per zoom: linee più sottili e colori più chiari in zoom alto; niente label duplicate.
6. Pubblicare e copiare il `map_id`; le modifiche si propagano in 1–2 ore [7].
7. Salvare nel repo una nota con palette, layer nascosti e `map_id`; se possibile esportare una copia dello style JSON come riferimento (senza key).

Il tile raster contiene i label “cotti”: se ne lasci troppi, le etichette resteranno fisse sotto gli edifici 3D e sembreranno sbagliate. Meglio pochi label o nessuno; i nomi si possono aggiungere in HUD/POI in una fase successiva.

### 8.5 API key non committata

Vincolo di progetto: niente backend. La key nell’APK **sarà estraibile**; l’obiettivo è non commetterla e limitare l’abuso.

Piano:

1. **`.gitignore`**: aggiungere `secrets.cfg` (e `*.secret.cfg`). Il file attuale non lo prevede; va aggiunto quando si implementa (questa ricerca non modifica altri file).
2. **`secrets.example.cfg`** committato con chiave vuota.
3. **Runtime**:
   - desktop: `OS.get_environment("MAPTILER_API_KEY")` se presente;
   - altrimenti `ConfigFile.load("res://secrets.cfg")`;
   - se manca la key: schermata “Configura MAPTILER_API_KEY”, niente tile OSM di fallback.
4. **Build Android**:
   - script pre-export legge `MAPTILER_API_KEY` dall’ambiente e scrive `res://secrets.cfg`;
   - export APK;
   - rimuove o lascia il file ignorato (non committare).
5. **Restrizione key** nel dashboard MapTiler: `Allowed User-Agent header` = `GDGPSGame/`.
6. **Rotazione** ogni 2–3 mesi o subito dopo un leak; revocare la vecchia key [4].
7. **Monitoraggio**: analytics MapTiler; alert a 70–80% della quota; stop locale al 90%.
8. **Niente log**: mai stampare la query string completa; redigere `key=...`.
9. **Consapevolezza**: chi ha l’APK può estrarre la key. Per questo il free plan (nessun overage) è adatto alla slice; se in futuro serve segretezza, serve un proxy backend (fuori scope).

Per Thunderforest/Stadia il piano è analogo, ma non hanno una allowlist `User-Agent` documentata: la key sarebbe ancora più “pubblica”. Un altro motivo per preferire MapTiler nella slice.

### 8.6 Attribuzione visibile

UI consigliata:

- **Barra persistente** in basso (o angolo) con:
  - logo MapTiler (free) → `https://www.maptiler.com/`
  - `© MapTiler` → `https://www.maptiler.com/copyright/`
  - `© OpenStreetMap contributors` → `https://www.openstreetmap.org/copyright`
- **Schermata “Licenze / About”** con:
  - testo completo delle attribuzioni;
  - link a ODbL/OSM copyright;
  - link ai termini MapTiler;
  - versione stile/map ID.
- Tap su logo/testo: `OS.shell_open(url)` (Android apre il browser).
- Non nascondere la barra dietro l’HUD o dietro un toggle; se si vuole ridurre l’ingombro, lasciare un’icona `(i)` sempre visibile che apre la schermata licenze.

OSMF per i giochi consente anche splash screen, crediti o menu [26], ma i termini MapTiler chiedono l’attribuzione sulla mappa [3][8]. La barra persistente soddisfa entrambi ed evita contestazioni. OSMF consente di collassare l’attribuzione dopo 5 secondi se resta accessibile via `(i)`/About [26]; per semplicità, nella slice teniamola sempre visibile.

### 8.7 Quota, cache e prefetch

- **Cache locale** LRU su disco, chiave `provider/style/z/x/y/scale`; memorizzare `ETag`/`Last-Modified` e rispettare `Cache-Control`/`Expires`. TTL massimo prudenziale: 7 giorni (allineato a OSM/Stadia; MapTiler non impone un TTL specifico, ma la cache deve restare “temporanea” e personale [2]).
- **Nessuna cache server-side**, nessun proxy, nessun download di area/offline pack: vietati da MapTiler [2] (e da Stadia/Thunderforest con regole diverse).
- **Prefetch**: solo tile visibili + 1 tile di margine; al massimo il livello di zoom successivo per l’area visibile, con un limite (es. 32 tile). Niente “scarica la città”.
- **Budget**: contatore locale di richieste; warning a 70%, stop a 90%; a quota esaurita mostrare tile in cache/placeholder, non passare a OSM.
- **Retina ibrido**: 256 px sotto z15, `@2x` da z15; riduce di ~4× il costo nelle viste ampie.
- **Max zoom**: 20; oltre, upscale. Se lo stile custom non ha tile a z20, impostare il massimo reale.

### 8.8 Uso di OSM solo in sviluppo

Se serve un fallback senza account per il desktop:

- attivarlo solo con `OS.is_debug_build()` **e** un flag esplicito `--dev-osm-tiles`;
- `User-Agent` dedicato e onesto: `GDGPSGame-dev/0.1 (+https://example.org; contact: ...)`;
- solo tile visibili, nessun prefetch, cache ≥7 giorni, nessun download offline;
- attribuzione `© OpenStreetMap contributors` con link;
- **fail build/CI** se `tile.openstreetmap.org` compare in una build di export o in un preset Android;
- preferibile: usare la key MapTiler anche in sviluppo, così il comportamento è lo stesso della build reale. OSM resta solo per un “primo avvio” senza configurazione.

### 8.9 Fallback e trigger di revisione

| Situazione | Azione |
|---|---|
| Il logo MapTiler nel free è inaccettabile | Stadia Free (Alidade Smooth, no logo, 200k) o Stadia Starter $20 (1M, commerciale) |
| Serve uso commerciale | MapTiler Flex $30 (500k richieste, commerciale) o Thunderforest Solo $125 (1.5M) |
| La quota retina 25k/mese non basta | MapTiler Flex (125k tile retina) o Thunderforest Hobby (150k, se @2x = 1 richiesta) |
| Serve stile custom raster + volume | MapTiler Flex; Stadia custom raster su preventivo; Thunderforest custom $245 + $55/mese |
| Serve zero logo e zero custom | Stadia Free con Alidade Smooth |
| Si passa a vector tile/MapLibre | Rivalutare Stadia/MapTiler vector; fuori scope della slice raster |
| Serve offline maps completo | Self-hosting/vector tile; `tile.openstreetmap.org` non è un'opzione |

---

## 9. Stima quota per la slice

Stima di ordine di grandezza, da misurare con il contatore locale:

- 100.000 richieste/mese ÷ 4 = **25.000 tile 512 px `@2x`/mese**.
- Una schermata portrait 1080×2400 con tile 512 px mostra ~2×5 = 10 tile; con 1 tile di margine ~4×7 = 28 tile “vive”.
- Una camminata di 30 minuti a 5 km/h attraversa pochi tile nuovi (z17: ~300 m per tile all’equatore); con cache e prefetch modesto, stimiamo **200–800 tile uniche per uscita**, non migliaia.
- 25.000 tile coprono decine di uscite nello stesso quartiere; la cache rende le uscite successive quasi gratuite.
- Se si usa `@2x` anche a zoom basso o si prefetcha troppo, il budget si consuma in fretta. Da qui il regime ibrido 256/`@2x`.

Se la stima reale supera ~20.000 tile/mese, passare a Flex prima di alzare il prefetch.

---

## 10. Rischi e mitigazioni

| Rischio | Impatto | Mitigazione |
|---|---|---|
| Logo MapTiler obbligatorio nel free | UI meno pulita | Barra piccola + About; se bloccante, Stadia Free/Starter |
| 512 px = 4 richieste | Quota consumata 4× | 256 sotto z15, `@2x` solo z≥15; contatore; Flex se serve |
| Key estratta dall’APK | Abuso quota | Free plan senza overage; restrizione `User-Agent`; rotazione; monitor |
| Stile custom solo nel cloud | Riproducibilità/outage | Documentare palette/layer/map ID; style JSON di riferimento; fallback `dataviz-v4` |
| Label cotti nel raster | Clutter sotto gli edifici 3D | Nascondere i symbol layer nello stile; pochi label |
| Prefetch troppo aggressivo | Violazione termini/bulk | Limite tile, solo vista corrente, no download area |
| Tile OSM nell’APK | Violazione policy, blocchi | Flag debug-only; check CI; niente fallback automatico |
| Provider down | Mappa vuota | Cache; placeholder; messaggio; nessun switch automatico a OSM |
| Termini cambiano | Rischio legale | Rileggere prima di release; conservare URL/data |
| Privacy posizione | IP+area al provider | HTTPS; niente ID utente nella URL; endpoint EU se serve; informativa |

---

## 11. Checklist di conformità

- [ ] Key in `secrets.cfg` ignorato, mai in `project.godot`, script, preset, log o commit.
- [ ] `secrets.example.cfg` committato con chiave vuota.
- [ ] Restrizione `User-Agent` configurata nel dashboard MapTiler.
- [ ] `User-Agent` inviato su ogni richiesta tile.
- [ ] Attribuzione MapTiler + OSM + logo visibile; link funzionanti su Android.
- [ ] Schermata Licenze/About con ODbL e link OSM.
- [ ] Cache solo on-device, TTL da header (max 7 giorni prudenziale).
- [ ] Nessun proxy/server cache; nessun bulk download.
- [ ] Prefetch limitato alla vista + margine.
- [ ] Contatore quota e stop al 90%; analytics MapTiler controllate.
- [ ] Nessun URL `tile.openstreetmap.org` in build di export.
- [ ] Se si usa OSM in dev: `User-Agent` dedicato, no prefetch, cache 7 giorni, attribuzione.
- [ ] `max_zoom` e stile verificati su device.
- [ ] Piano free ancora compatibile con l’uso (non commerciale/R&D).

---

## 12. Fonti

Tutte consultate il **31 ottobre 2026**.

1. **MapTiler — Pricing**  
   https://www.maptiler.com/cloud/pricing/  
   (piano Free, 100k API requests, 5 custom styles, 1 API key, logo, conteggio 512 px = 4 richieste, pausa a quota)

2. **MapTiler — Cloud Terms and Conditions**  
   https://www.maptiler.com/terms/cloud/  
   (free non commerciale/R&D, cache end-user, divieto proxy/server cache/bulk)

3. **MapTiler — General Terms and Conditions**  
   https://www.maptiler.com/terms/  
   (attribuzione MapTiler/OSM, logo free, divieto di modifica di pixel/vector/metadata)

4. **MapTiler — API key**  
   https://docs.maptiler.com/guides/developer/credentials/api-key/  
   (`Allowed User-Agent header` per app native, rotazione, quota free)

5. **MapTiler — Maps API**  
   https://docs.maptiler.com/cloud/api/maps/  
   (endpoint raster XYZ, `mapId`, `tileSize`, `@2x`)

6. **MapTiler — Sessions vs requests**  
   https://docs.maptiler.com/guides/account/sessions-vs-requests/  
   (tracking per request con client terzi; tabella 256=1, 512=4)

7. **MapTiler — Publish a custom map**  
   https://docs.maptiler.com/guides/map-design/how-to-publish-a-map/  
   (stile custom pubblicato, usabile in mobile app; propagazione 1–2 ore)

8. **MapTiler — Map attribution**  
   https://docs.maptiler.com/guides/map-design/attribution/add-attribution/  
   (testo `© MapTiler` + `© OpenStreetMap contributors`, logo free, giochi/video)

9. **MapTiler — Map data licenses / copyright**  
   https://www.maptiler.com/copyright/  
   (ODbL/OSM, attribuzione minima, esempio `dataviz-v4`)

10. **MapTiler — Layer styling**  
    https://docs.maptiler.com/guides/map-design/editor/layers/styling/  
    (fill/outline/opacity, styling per layer)

11. **MapTiler — Style by zoom range**  
    https://docs.maptiler.com/guides/map-design/editor/layers/zoom-range/  
    (colori/width/label per intervallo di zoom)

12. **Thunderforest — Pricing**  
    https://www.thunderforest.com/pricing/  
    (Hobby 150k tile/mese free; definizione di request; piani a pagamento)

13. **Thunderforest — Terms and Conditions**  
    https://www.thunderforest.com/terms/  
    (commercial use, CC-BY-SA 4.0, cache on-device, bulk download, attribution, throttle)

14. **Thunderforest — API Keys**  
    https://www.thunderforest.com/docs/apikeys/  
    (1 key nel free, key nel URL, rotazione via supporto)

15. **Thunderforest — Map Tiles API**  
    https://www.thunderforest.com/docs/map-tiles-api/  
    (URL `{style}/{z}/{x}/{y}{scale}.{format}?apikey=`, `@2x`)

16. **Thunderforest — Custom Cartography**  
    https://www.thunderforest.com/custom/  
    (custom $245 setup + $55/mese; test con stile esistente sul free)

17. **Stadia Maps — Pricing**  
    https://stadiamaps.com/pricing/  
    (Free 200k crediti, 1 credito/tile raster, 14-day trial, commercial use not allowed)

18. **Stadia Maps — Service Limits**  
    https://docs.stadiamaps.com/limits/  
    (free per sviluppo/valutazione/non commerciale, hard limit 429, no proxy/bulk)

19. **Stadia Maps — Authentication**  
    https://docs.stadiamaps.com/authentication/  
    (API key per mobile; attenzione a non committare; rotazione)

20. **Stadia Maps — Raster Map Tiles**  
    https://docs.stadiamaps.com/raster/  
    (256/512 px, endpoint `{r}`/`@2x`, max zoom 20, key per mobile)

21. **Stadia Maps — Custom Map Styling**  
    https://docs.stadiamaps.com/custom-styles/  
    (vector custom con MapLibre; raster custom “contact us for a quote”)

22. **Stadia Maps — Terms of Service**  
    https://stadiamaps.com/terms-of-service/  
    (free non commerciale; cache mobile max 100 MB; 7 giorni/header; no server cache)

23. **Stadia Maps — Required Attribution**  
    https://docs.stadiamaps.com/attribution/  
    (`© Stadia Maps © OpenMapTiles © OpenStreetMap`, link obbligatori)

24. **OpenStreetMap Foundation — Tile Usage Policy**  
    https://operations.osmfoundation.org/policies/tiles/  
    (URL ufficiale, User-Agent, cache 7 giorni, no prefetch/offline, no SLA, accesso revocabile)

25. **OpenStreetMap — Copyright and License**  
    https://www.openstreetmap.org/copyright  
    (ODbL, obbligo di credito e link alla licenza)

26. **OpenStreetMap Foundation — Attribution Guidelines**  
    https://osmfoundation.org/wiki/Licence/Attribution_Guidelines  
    (mappe interattive: corner; giochi: splash/credits/menu; collapse dopo 5 s con accesso a licenza)

27. **Stadia Maps — Map Style Library**  
    https://docs.stadiamaps.com/themes/  
    (Alidade Smooth: muted, fewer POIs)

28. **Thunderforest — Maps**  
    https://www.thunderforest.com/maps/  
    (Atlas, Atlas Canvas, Landscape, Outdoors, ecc.)

---

## Appendice — Sintesi delle citazioni decisive

- **MapTiler free**: “100k API requests/month”, “Custom map styles 5”, “API keys 1”; 512 px = 4 richieste [1][6].
- **MapTiler stile**: pubblicabile come `mapId` e usabile in mobile app [7]; raster XYZ con `@2x` [5].
- **MapTiler key**: restrizione `Allowed User-Agent header` per app native [4].
- **MapTiler termini**: free solo non commerciale/R&D [2]; cache personale sì [2]; proxy/bulk/modifica no [2][3]; logo free [3][8].
- **Thunderforest**: 150k free [12]; custom a $245 + $55/mese [16]; `@2x` [15]; cache on-device sì [13]; commerciale sì [13]; attribution Thunderforest+OSM [13].
- **Stadia**: 200k crediti, 1/tile raster [17]; custom raster su preventivo [21]; free non commerciale [18][22]; cache 100 MB/7 giorni [22]; attribution Stadia+OpenMapTiles+OSM [23].
- **OSM standard**: no SLA, no prefetch/offline, User-Agent obbligatorio, cache 7 giorni, accesso revocabile [24]; solo dev, mai APK.
