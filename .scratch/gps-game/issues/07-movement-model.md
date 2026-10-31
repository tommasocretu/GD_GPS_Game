# Modello di movimento e smoothing GPS

Type: grilling
Status: resolved
Blocked by: —

## Question

Definire come il GPS diventa movimento dell'avatar: soglia di precisione, filtro dei fix, interpolazione tra campioni, jitter da fermo, salti/teleport, velocità massima plausibile, direzione di marcia, animazione idle/walk e comportamento in assenza di fix. Decidere anche cosa mostra l'HUD di debug. HITL: richiede le preferenze del giocatore.

## Answer

**Decisione:** pipeline a tre stadi — validazione dei fix, target filtrato pesato sull'accuratezza, inseguimento visivo con molla critica smorzata — più un rilevatore di immobilità e una politica esplicita per le anomalie. Niente Kalman, niente collisioni, niente movimento quando il GPS non è affidabile.

L'avatar è un **indicatore GPS**, non un personaggio fisico: la posizione "vera" è il fix, quella visiva è una versione filtrata e smorzata. L'obiettivo è un avatar stabile con ritardo percepito ≤1 s, non la replica esatta del rumore GNSS.

### Parametri

Tutti i valori stanno in un unico `movement_config.gd` esportato; gli identificatori nel codice sono in inglese.

| Parametro | Valore | Note |
|---|---:|---|
| Intervallo GPS richiesto | 1000 ms (min 500, min distance 1 m) | da research 01 |
| Età massima di un fix | 2 s | usa `elapsed_ns` monotono |
| Accuracy OK | ≤30 m | stato `OK` |
| Accuracy debole | 30–50 m | stato `WEAK`, movimento rallentato |
| Accuracy rifiutata | >50 m | nessun movimento, si tiene l'ultima posizione |
| Finestra del target | ultimi 2 fix validi | pesi `1/accuracy²` |
| Outlier | distanza > `max(3 m, 2×accuracy)` dal target | accettato solo se il fix successivo lo conferma |
| `smooth_time` | 0,45 s | molla critica smorzata |
| Velocità massima di tracking | 2,5 m/s | solo inseguimento normale |
| Correzione 3–15 m | easing in 0,8 s | può superare 2,5 m/s |
| Soglia di snap | >15 m, oppure buco >10 s | fade 0,15 s + evento HUD |
| Lock da fermo | `speed < 0,35 m/s` per 2 s | fallback: spostamento netto <2 m in 4 s |
| Rilascio del lock | >3 m dal punto di lock o `speed > 0,6 m/s` | nessun salto al rilascio |
| Velocità in `WEAK` | max 0,8 m/s, `smooth_time` 1,0 s | |
| Soglia Idle/Walk | 0,3 m/s | blend 0,2 s |
| Soglia Walk/Run | 2,5 m/s | Run solo con fake GPS |
| Rotazione massima | 180°/s | heading dal movimento |
| Anchor iniziale | primo fix con accuracy ≤20 m | altrimenti stato `INIT` |

### Pipeline

```
fix Android ──► validazione ──► filtro target ──► molla/visivo ──► avatar
                    │                │                 │
                 scarta          2 fix pesati      correzioni e snap
                 età/accuracy    + outlier          lock/heading/anim
```

#### 1. Validazione

- Scartare fix con età >2 s (tipico dopo resume: Android può consegnare fix cachati).
- Scartare `accuracy > 50 m`; tra 30 e 50 m il fix è valido ma lo stato è `WEAK`.
- `is_mock` non blocca nulla: è solo un flag HUD.
- Un fix che dista più di `max(3 m, 2×accuracy)` dal target corrente è un **candidato outlier**. Non si applica subito: se il fix successivo è coerente con il candidato (stessa soglia), allora è movimento vero e si applica la politica di correzione/snap; altrimenti il candidato viene scartato.
- Un fix senza predecessore valido inizializza il target.

#### 2. Target filtrato

Media pesata `1/accuracy²` degli ultimi due fix validi:

```
w_i = 1 / accuracy_i²
target = (w_1 · fix_1 + w_2 · fix_2) / (w_1 + w_2)
```

Se i due fix hanno accuratezza simile il peso è 50/50; un fix da 5 m contro uno da 30 m pesa ~97%. Con un solo fix valido, il target è quel fix. La media a due campioni aggiunge ~0,5 s di ritardo, compensato in parte dalla molla.

#### 3. Inseguimento visivo

- Molla **critica smorzata** (SmoothDamp) integrata in `_process`, non in `_physics_process`: il movimento è visivo e non ci sono collisioni, quindi resta fluido anche a 120 Hz. `delta` clampato a 0,1 s per non esplodere dopo un hitch.
- `smooth_time` 0,45 s; `max_speed` 2,5 m/s per il tracking normale.
- 3–15 m di correzione: profilo dedicato con easing in 0,8 s, che può superare temporaneamente il limite di velocità.
- Oltre 15 m, o buco >10 s: snap immediato, fade 0,15 s, evento `SNAP` in HUD con distanza e motivo.
- In `WEAK`: `max_speed` 0,8 m/s e `smooth_time` 1,0 s.
- Accuracy >50 m: il target non cambia e l'avatar resta fermo.

#### 4. Immobilità

- Se il fix espone `hasSpeed()`, usare la `speed` Doppler Android, molto meno rumorosa della posizione.
- Lock dopo 2 s consecutivi con `speed < 0,35 m/s`. Fallback senza speed: spostamento netto <2 m in 4 s.
- Al lock il target viene congelato sul punto di lock e l'animazione va in Idle; i fix continuano ad arrivare per capire quando ripartire.
- Rilascio quando il fix si allontana >3 m dal punto di lock o `speed > 0,6 m/s`. Al rilascio il target torna all'ultimo fix valido e la molla riparte dal punto di lock, senza salto.
- La soglia bassa (0,35 m/s) evita di congelare una passeggiata lenta.

#### 5. Heading e animazioni

- Heading calcolato dallo spostamento del target filtrato su una finestra di ~2 m di tragitto, non dal `bearing` Android (invalido a bassa velocità e rumoroso).
- Aggiornamento solo sopra 0,5 m/s; da fermo l'avatar mantiene l'ultima direzione.
- Rotazione verso il nuovo heading con limite di 180°/s; niente snap di rotazione.
- Modello con fronte `+Z`: usare `look_at(..., UP, use_model_front = true)`.
- Animazioni: `Idle` sotto 0,3 m/s, `Walk` tra 0,3 e 2,5 m/s, `Run` sopra 2,5 m/s (solo fake GPS). Crossfade 0,2 s.
- Playback a velocità fissa 1.0 nella slice. Se nel prototipo 11 il foot sliding sarà evidente, valutare il `speed_scale = clamp(speed / 1.32, 0.8, 1.2)` già previsto dal ticket 06.

#### 6. Nessuna collisione

- L'avatar si muove a `y = 0` e attraversa i volumi degli edifici: sono rappresentazione visiva, non ostacoli fisici.
- Niente `CharacterBody3D`/`move_and_slide` per il movimento GPS, niente navmesh. La capsula 1,8 m del ticket 06 resta solo come riferimento visivo.
- L'occlusione dietro gli edifici è un problema di camera/composizione (ticket 08), non di fisica.

### Stati GPS

| Stato | Condizione | Comportamento |
|---|---|---|
| `INIT` | nessun anchor ancora creato | avatar fermo, HUD "GPS in attesa" |
| `OK` | ultimo fix ≤2 s, accuracy ≤30 m | tracking normale |
| `WEAK` | ultimo fix ≤2 s, accuracy 30–50 m | tracking lento (0,8 m/s) |
| `STALE` | ultimo fix >2 s e ≤10 s | avatar fermo sull'ultima posizione |
| `LOST` | ultimo fix >10 s | avatar fermo, banner persistente |
| `DENIED` | permesso posizione negato | nessuna richiesta in loop, HUD con istruzioni |

- L'anchor iniziale si crea solo con un fix `accuracy ≤ 20 m`; prima lo stato resta `INIT`.
- Banner "GPS in attesa" dopo 5 s senza `OK`/`WEAK`; banner persistente in `LOST`.
- Al resume, i fix cachati più vecchi di 2 s vengono scartati: si riparte da `STALE` o `LOST` (o `INIT` se non c'è ancora un anchor), senza recupero della posizione persa.
- `DENIED` è terminale finché il permesso non viene concesso; il passaggio a `INIT` riavvia la pipeline.

### HUD di debug

Campi always-on nelle build di debug:

- stato GPS, età del fix, `accuracy`, `is_mock`;
- lat/lon a 6 decimali, velocità, heading in gradi;
- distanza dall'anchor e chunk corrente;
- FPS;
- ultimo evento `SNAP` (distanza, motivo, timestamp).

Strumenti opzionali:

- marker magenta (sfera 0,3 m a `y = 0,1`) sul fix grezzo, toggle dall'HUD;
- pannello con tre slider live: `smooth_time`, soglia di lock, `max_speed`;
- pannello e marker assenti nelle build di release.

### Rebase e cambio zona

- Il target filtrato e il punto di lock vivono nel frame locale in metri; al rebase (ticket 04, ogni 2 km) vengono traslati dello stesso `shift` del `WorldRoot`. Il rebase non produce snap né eventi HUD.
- L'ultimo fix valido resta in lat/lon `float64` per HUD e persistenza.
- Al cambio di anchor (zona >4 km o città nuova) filtro, lock e heading ripartono da zero; il primo fix della nuova zona è un teleport e produce un singolo snap.

### Test di accettazione

Test headless con tracce sintetiche deterministiche (JSON con timestamp, lat/lon, accuracy, speed):

| Caso | Pass criteria |
|---|---|
| Fermo 60 s, rumore σ = 5 m | dopo il lock l'avatar si sposta <0,5 m; animazione Idle |
| Rettilineo 100 m a 1,4 m/s, σ = 5 m | errore RMS <2 m, massimo <5 m, nessuno snap |
| Salto di 10 m | recupero in ≤0,8 s, un solo evento di correzione, nessuno snap |
| Salto di 40 m | un solo snap, fade e evento HUD |
| Fix stantio | nessun movimento dopo 2 s; `STALE`; `LOST` dopo 10 s |
| Accuracy 40 m | velocità ≤0,8 m/s, stato `WEAK` |
| Ripresa da pausa con fix di 30 s | fix scartato, nessun movimento, `STALE` |
| Outlier isolato | scartato; se ripetuto e coerente, accettato |
| Heading | aggiornato solo in movimento, rotazione ≤180°/s |
| Rebase a 2 km | posizione geografica invariata, nessun salto visivo |

Test sul campo (Fairphone Gen 6): 100 m rettilinei, 60 s da fermo, 5 min in centro urbano, 1 km totale. Verificare jitter residuo, drift sistematico, numero e posizione degli snap, comportamento dietro gli edifici, ripresa dopo pausa. I criteri end-to-end e il protocollo completo restano nel ticket 12.

### Note e questioni residue

- **Foot sliding:** il playback fisso è la scelta della slice; il `speed_scale` si valuta solo se il prototipo 11 lo rende necessario.
- **Occlusione:** un edificio alto può nascondere l'avatar. È materia del ticket 08 (camera e composizione), non del modello di movimento.
- **Canyon urbano:** con accuracy stabilmente >50 m l'avatar resta fermo. È voluto: meglio un avatar fermo che uno che corre tra i palazzi. Il ticket 12 deve dire per quanto tempo è accettabile.
- **Fake GPS:** la sorgente simulata (WASD/registrazione) è parte del prototipo 11; qui è definito solo il contratto dei fix.
- **Batteria:** il modello non cambia la frequenza GPS (1 Hz, foreground); non introduce polling aggiuntivo.
