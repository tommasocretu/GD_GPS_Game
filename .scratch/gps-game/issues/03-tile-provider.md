# Provider tile OSM free-tier e attribuzione

Type: research
Status: resolved
Blocked by: —

## Question

Quale provider usare per le tile OSM nella slice, considerando free tier, API key per app mobile, stile personalizzabile/low-poly, tile retina, quota, termini d'uso e attribuzione?

Confrontare almeno MapTiler, Thunderforest, Stadia Maps e l'uso di `tile.openstreetmap.org` solo in sviluppo. Output: scelta raccomandata, piano per la API key (non committata), URL/stile, limiti e fonti. Findings in `.scratch/gps-game/research/03-tile-provider.md`.

## Answer

**Scelta: MapTiler Cloud Free + stile custom pubblicato come raster XYZ.**

- È l'unico free con stile raster custom self-service (5 stili, Map Designer): palette flat, layer POI/label/hillshade nascosti, look low-poly.
- Quota: 100.000 richieste/mese; tile 512 px `@2x` = 4 richieste → ~25.000 tile retina/mese; a quota esaurita il servizio si ferma (nessun overage).
- Retina: `https://api.maptiler.com/maps/{MAP_ID}/256/{z}/{x}/{y}@2x.png?key={KEY}`; 256 px sotto z15, `@2x` da z15.
- API key: restrizione `Allowed User-Agent header` (`GDGPSGame/`), key in `secrets.cfg` ignorato + `secrets.example.cfg` + env `MAPTILER_API_KEY`; mai in `project.godot`/commit/log. Nell'APK è estraibile: free plan, rotazione, monitor quota.
- Attribuzione: `© MapTiler © OpenStreetMap contributors` + logo MapTiler (free) in barra persistente, link a maptiler.com/copyright e openstreetmap.org/copyright; schermata Licenze/About.
- Free solo non commerciale/R&D; cache solo on-device, no proxy/bulk/prefetch esteso. `tile.openstreetmap.org` solo dev desktop (User-Agent, cache 7 giorni, no prefetch/offline), mai nell'APK.
- Fallback: Thunderforest Hobby (150k, custom a pagamento) o Stadia Free (200k, no logo, custom raster su preventivo); upgrade MapTiler Flex $30 (500k richieste, commerciale).

Report: [03-tile-provider.md](../research/03-tile-provider.md)
