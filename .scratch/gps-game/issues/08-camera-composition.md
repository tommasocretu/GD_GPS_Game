# Camera, inquadratura e composizione visiva

Type: grilling
Status: resolved
Blocked by: —

## Question

Fissare i dettagli della camera obliqua north-up: angolo, altezza, distanza, zoom, smoothing del follow, safe area portrait, scala dell'avatar rispetto agli edifici, illuminazione/nebbia per nascondere i bordi del mondo. HITL.

## Answer

**Decisione:** camera prospettica fissa, north-up, FOV verticale 50°, pitch 27° sotto l'orizzonte, offset di 13 m in altezza e 18,5 m a sud dell'avatar. L'avatar sta al 65% dell'altezza schermo e occupa circa l'8,8%; il suolo visibile arriva a ~350 m avanti e ~8 m dietro. Follow esponenziale da 0,15 s, braccio di collisione per l'occlusione, HUD dentro la safe area, giorno fisso con nebbia 180–320 m, avatar 1:1. Nessuno zoom e nessuna rotazione di gioco.

Il north-up fisso è accettato con la sua asimmetria: camminando verso sud si vede poco avanti, perché il bordo basso dello schermo cade a ~8 m dietro l'avatar. Non è un difetto correggibile con l'inquadratura: centrare l'avatar o aggiungere look-ahead non sposta il bordo basso e può portare la camera davanti all'avatar. Il field test del ticket 12 può riaprire la decisione e passare a una camera che segue l'heading.

### Parametri

Tutti i valori stanno in un unico `camera_config.gd` esportato; gli identificatori nel codice sono in inglese.

| Parametro | Valore | Note |
|---|---:|---|
| Proiezione | Prospettica | Niente ortografica |
| FOV verticale | 50° | `keep_aspect = KEEP_HEIGHT` |
| Near / far | 0,1 m / 400 m | Il far copre il bordo della nebbia |
| Pitch | 27° sotto l'orizzonte | `rotation.x = -27°` |
| Offset camera | `(0, 13, 18.5)` m | +Z = sud; distanza ~22,6 m |
| Avatar a schermo | 65% verticale, 50% orizzontale | a riposo |
| Altezza apparente avatar | ~8,8% | 1,858 m a 22,6 m, FOV 50° |
| Suolo visibile | ~350 m avanti, ~8 m dietro | bordo alto/basso |
| Follow | tau 0,15 s | smorzamento esponenziale |
| Fade snap | 0,15 s | taglio al picco del fade |
| Fade primo anchor | 0,3 s | camera già nella posizione finale |
| Braccio di collisione | min 8 m, sfera 0,3 m, margine 0,3 m | solo edifici |
| Recovery braccio | 0,2 s | allungamento dopo l'ostacolo |
| Nebbia | 180–320 m | lineare/depth, colore = sfondo |
| Sfondo | `#cfd8cc` (placeholder) | palette definitiva nel prototipo 09 |
| Scala avatar | 1,0 | 1,858 m, nessun upscale |
| Zoom di gioco | Nessuno | né pinch né rotazione |

### Camera rig

```
WorldRoot
└─ CameraRig              # yaw 0, segue l'avatar in x/z, y = 0
   └─ Camera3D            # offset (0, 13, 18.5), rotazione (-27°, 0, 0)
```

- La camera non ruota e non guarda l'avatar con `look_at` ogni frame: l'orientamento è fisso, l'offset è ciò che mette l'avatar al 65%.
- Il braccio di collisione accorcia solo la posizione lungo la congiungente avatar–camera; l'orientamento resta `(-27°, 0, 0)`. A lunghezza ridotta l'avatar resta al 65%, ma diventa più grande.
- `Camera3D.position_smoothing` va lasciato disattivato: lo smoothing è nel `CameraRig`, altrimenti si sommano due ritardi.
- Aggiornamento in `_process`, con `process_priority` successivo a quello del player; `delta` clampato a 0,1 s come nel modello di movimento.
- Niente camera shake, bob, rollio o effetti cinematici.

### Composizione e north-up

- L'avatar resta orizzontalmente al centro; nessun look-ahead. Un offset in direzione di marcia sposterebbe la camera oltre l'avatar o fuori composizione.
- Lo yaw è sempre 0: la mappa non ruota con il giocatore. La rotazione manuale a due dita è fuori scope per la slice.
- Camminando verso sud si vede poco avanti; è accettato. Se il field test 12 lo trova frustrante, la fallback è una camera che segue l'heading (yaw = direzione di marcia, bussola HUD), da decidere in quel ticket.
- Il portrait è bloccato; con `KEEP_HEIGHT` la composizione verticale resta stabile tra i dispositivi, mentre il campo orizzontale si restringe sui display molto alti.

### Follow e stati GPS

| Stato / evento | Comportamento camera |
|---|---|
| `OK` / `WEAK` | Follow normale, tau 0,15 s |
| `SNAP` del modello 07 | Taglio istantaneo sulla nuova posizione, fade 0,15 s; nessun volo attraverso la mappa |
| Primo anchor valido | Camera posizionata subito, fade-in 0,3 s |
| `INIT` | Overlay di attesa; il mondo non è ancora mostrato |
| `STALE` | Camera ferma sull'ultima posizione |
| `LOST` | Camera ferma, banner persistente |
| `DENIED` | Overlay con istruzioni; nessun mondo finto |
| Rebase (ticket 04) | Camera figlia di `WorldRoot`, traslata con il mondo: nessun salto o fade |

- In `STALE`/`LOST` l'avatar è già fermo: la camera si limita a smettere di inseguire.
- Il rebase non produce eventi HUD né snap, come nel modello di movimento.
- Al ritorno da pausa con fix scartati, la camera resta sull'ultima posizione nota; non recupera la posizione persa.

### Occlusione

- Braccio di collisione (SpringArm3D o raycast equivalente) dal petto dell'avatar (`y = 1,2`) alla posizione desiderata della camera.
- I chunk degli edifici ricevono un collider trimesh statico su un layer dedicato (es. layer 2); il terreno e l'avatar non sono nel mask. Il movimento dell'avatar resta senza collisioni.
- Lunghezza minima 8 m, sfera 0,3 m, margine 0,3 m. L'accorciamento è immediato per evitare clipping; l'allungamento usa 0,2 s per non "pompare".
- Nessuna trasparenza o fade degli edifici: un chunk è una mesh unica e non si può nascondere il singolo edificio.
- Fallback se il costo dei collider o i cambi di lunghezza risultano fastidiosi nel prototipo 11: niente collider e marker sempre visibile sopra la testa (sfera/billboard a `y = 2,2`, senza depth test). La scelta si fa sul dispositivo.

### HUD e safe area

- Viewport 3D full-bleed; l'HUD vive dentro `DisplayServer.get_display_safe_area()`, con margini per notch, status bar e gesture bar. Portrait bloccato.
- In alto: pill di stato GPS (stato, età del fix, accuracy, `is_mock`) e, sotto, il pannello debug del ticket 07 (lat/lon a 6 decimali, velocità, heading, distanza dall'anchor, chunk, FPS, ultimo `SNAP`).
- In basso: barra attribuzione `© MapTiler © OpenStreetMap contributors` + logo, alta ~44 dp più il safe inset; sopra la barra, toast `SNAP` con distanza, motivo e timestamp, auto-hide 3 s.
- Banner "GPS in attesa" dopo 5 s senza `OK`/`WEAK`; banner persistente in `LOST`; istruzioni in `DENIED`.
- In `INIT`/`DENIED`: overlay a schermo intero su colore nebbia, con icona, testo e spinner; nessun mondo finto. Al primo fix `accuracy ≤ 20 m` il mondo fa fade-in in 0,3 s.
- Nessun joystick, pulsante di movimento o controllo camera in gioco.
- Marker del fix grezzo e slider live (`smooth_time`, soglia di lock, `max_speed`) solo nelle build di debug e nascosti in release.
- Stile, font e palette definitivi si fissano nel prototipo 09.

### Luce, nebbia e bordi del mondo

- Giorno fisso, nessun ciclo giorno/notte. Una `DirectionalLight3D` da nord-ovest a 45° di elevazione, energia 1,0, **senza ombre realtime**.
- Ambiente neutro a energia ~0,7; nessun SSAO/SSR/SDFGI (il renderer Mobile non li ha).
- Terreno `unshaded` con la tile; edifici lit con vertex color, `roughness = 1`, `metallic = 0`, niente trasparenza. La nebbia si applica a entrambi.
- `WorldEnvironment`: `background_mode = BG_COLOR`, colore uguale alla nebbia; nebbia depth da 180 a 320 m; far plane 400 m. Niente cielo: il bordo del mondo sparisce nella foschia prima del far plane.
- Avatar a scala 1:1 (1,858 m), nessun upscale. Maglietta con colore saturo tramite `surface_override_material` per il contrasto; rim light solo se il prototipo 11 mostra poca leggibilità.
- Palette provvisoria `#cfd8cc` per sfondo/nebbia; colori definitivi nel prototipo 09.

### Test di accettazione

| Caso | Pass criteria |
|---|---|
| 1080×2400 portrait | Avatar al 65% ±2%, altezza apparente 8,5–9,5%, nessun clipping |
| 1080×1920 e 1440×3120 | Composizione verticale stabile; il crop orizzontale è accettabile |
| North-up | Yaw sempre 0; l'avatar resta al 50% orizzontale in ogni direzione |
| Follow | Ritardo percepito ≤0,2 s; nessuna oscillazione; stop in ≤0,3 s |
| Snap di 40 m | Fade 0,15 s, nessun volo visibile, evento HUD |
| Primo anchor | Overlay fino ad accuracy ≤20 m, poi fade-in 0,3 s |
| `STALE`/`LOST`/`DENIED` | Camera ferma o overlay; nessun movimento o mondo finto |
| Occlusione | Edificio tra camera e avatar: braccio ≥8 m, nessun clipping, recovery ≤0,3 s, avatar visibile |
| Rebase a 2 km | Nessun salto visivo |
| Bordi | Nessun seam tra ground, nebbia e sfondo; nessun cielo visibile |
| Safe area | HUD fuori da notch/status/gesture bar sul Fairphone Gen 6; 3D full-bleed |
| Performance | 60 fps target; il raycast camera è trascurabile |
| Debug | Camera libera e vista dall'alto solo in debug; nessun gesto in release |

### Note e questioni residue

- **North-up:** l'asimmetria di visibilità è una scelta consapevole. Se il field test 12 la boccia, la fallback è la camera heading-follow, non un look-ahead.
- **Collider camera:** costo da misurare nel prototipo 11; il fallback marker evita i collider ma perde l'occlusione realistica.
- **FOV e pitch:** 50°/27° sono il punto di partenza. Se in portrait il campo orizzontale risulta troppo stretto, il parametro da muovere è il FOV, non lo zoom.
- **Stile:** palette, materiali e HUD definitivi restano al prototipo 09; qui sono fissati solo composizione e comportamento.
- **Zoom e rotazione manuale:** fuori scope per la slice; si valutano solo dopo il field test.
