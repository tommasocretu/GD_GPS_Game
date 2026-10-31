# GPS input in Godot 4.7 su Android

Type: research
Status: resolved
Blocked by: —

## Question

Qual è il modo più affidabile per ottenere aggiornamenti GPS su Android da Godot 4.7.2, evitando dipendenze non mantenute?

Valutare almeno:

- API built-in di Godot per la posizione (se esiste).
- Plugin della community: nome, versione, stato di manutenzione, licenza, compatibilità con Godot 4.7.
- Plugin Android custom via Godot Android Plugin v2 / JNI, con codice Kotlin o Java.
- Permessi runtime (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`) e comportamento con permesso negato.
- Frequenza e precisione degli aggiornamenti, comportamento a schermo spento e in background.

Output atteso: raccomandazione motivata, rischi, schema minimo GDScript ↔ Android e fonti primarie. Findings in `.scratch/gps-game/research/01-gps-input.md`.

## Answer

**Raccomandazione:** plugin Android v2 interno (`GpsPlugin`) su `LocationManager` di piattaforma, `FUSED_PROVIDER` su API 31+ con fallback GPS/NETWORK; **niente Google Play Services**. Permessi `ACCESS_COARSE_LOCATION` + `ACCESS_FINE_LOCATION` nel manifest del plugin, richiesti con `OS.request_permissions()`; un segnale `location_fix(Dictionary)` emesso con `emitSignal` (marshalling sul render thread). Parametri: 1 Hz, min 500 ms, min 1 m, alta precisione.

**Motivi:** Godot 4.7 non ha API GPS built-in (la PR #47702 è chiusa senza merge). Nessun plugin community è insieme mantenuto, testato su 4.7, senza GMS e con dati/permessi/background adeguati: Praxis è archiviato, Karim è fermo al 2024, gli altri usano Play Services o hanno minSdk/frequenze problematiche. `JavaClassWrapper` può chiamare Android da GDScript, ma le callback di `LocationListener` entrano in GDScript sul thread Java (rischio threading), mentre `emitSignal` è il percorso supportato.

**Background:** per la vertical slice solo foreground + `DisplayServer.screen_set_keep_on(true)` e stop in pausa; Godot sospende il main loop a schermo spento. Il background vero richiede foreground service `location` (Android 14+: `FOREGROUND_SERVICE_LOCATION`) e buffer nativo: ticket separato.

**Rischi principali:** manutenzione del plugin interno e ABI Godot; permesso approssimativo/negato; jitter GPS in città; Doze/OEM battery killer in background; mock location.

Report completo con fonti primarie e snippet minimi: [`.scratch/gps-game/research/01-gps-input.md`](../research/01-gps-input.md).
