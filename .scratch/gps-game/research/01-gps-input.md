# GPS input su Godot 4.7.2 / Android 16 — ricerca

**Ticket:** `.scratch/gps-game/issues/01-gps-input-godot-android.md`
**Data:** 2026-10-31
**Perimetro:** Godot 4.7.2 stable, progetto mobile, Fairphone Gen 6 (Android 16), distribuzione APK (non Play Store), min SDK 26.

---

## TL;DR — raccomandazione

**Costruire un plugin Android v2 minimale interno** (`GpsPlugin`) che usa l'API di piattaforma `android.location.LocationManager`:

- provider `FUSED_PROVIDER` su Android 12+ (API 31+), con fallback a `GPS_PROVIDER` e `NETWORK_PROVIDER`;
- **nessuna dipendenza da Google Play Services** (niente `play-services-location`);
- permessi `ACCESS_COARSE_LOCATION` + `ACCESS_FINE_LOCATION` dichiarati nel manifest del plugin e richiesti da GDScript con `OS.request_permissions()`;
- un segnale Godot con un `Dictionary` per ogni fix (`latitude`, `longitude`, `accuracy`, `altitude`, `speed`, `bearing`, `time_ms`, `elapsed_ns`, `is_mock`);
- 1 Hz, minimo 500 ms, distanza minima 1 m, qualità alta;
- per la vertical slice: **solo foreground**, con `DisplayServer.screen_set_keep_on(true)` e stop degli update quando l'app va in pausa. Il background vero (schermo spento/app in background) richiede un foreground service `location` e un buffer nativo: da rimandare a un ticket separato.

Nessun plugin community soddisfa insieme manutenzione, compatibilità dichiarata con 4.7, assenza di Play Services e dati sufficienti. Il più vicino è `KarimIbrahim/Godot-Geolocation-Android`, ma è fermo al 2024 e espone solo lat/lon.

---

## 1. Versioni e stato verificati

| Elemento | Valore verificato | Fonte |
|---|---|---|
| Godot | `4.7.2-stable`, pubblicata 2026-08-18 | [G19] |
| Documentazione | docs "stable" = Godot 4.7 | [G1], [G4] |
| Android library Godot | `org.godotengine:godot:4.7.2.stable` su Maven Central | [G20] |
| Default Godot 4.7.2 | `minSdk 24`, `compileSdk 36`, `targetSdk 36`, JDK 17, Kotlin 2.1.21, AGP 8.6.1 | [G10], [G11] |
| Progetto | min SDK preferito 26; target device Android 16 (API 36) | `map.md` |
| Plugin system | Android plugin **v2**, richiede Godot 4.2+ e Gradle build | [G4] |

Nota: il progetto può impostare `minSdk 26` nell'export preset; Godot 4.7.2 accetta override purché ≥ 24 [G11]. Il plugin va compilato con `minSdk 26` (o 24) per non violare il manifest merger [A12].

---

## 2. API built-in di Godot per la posizione: non esiste

La documentazione 4.7 della classe `OS` espone i permessi (`request_permission`, `request_permissions`, `get_granted_permissions`, `revoke_granted_permissions`) ma nessuna API di localizzazione [G1]. Anche `Input` non ha metodi GPS/geolocation: la classe `Input` riguarda input, sensori e vibrazione, non la posizione [G2].

L'unica proposta nota è la PR `godotengine/godot#47702` "Add GPS functionality for Android" (2021), che aggiungeva `start_gps_tracker()` / `get_location()` a `Input`: è stata **chiusa senza merge** (`merged: false`) [G3]. Non risulta una classe `Geolocation` o `Location` nel class index 4.7 [G22].

**Conseguenza:** per ottenere la posizione serve un bridge Android (plugin v2). Le alternative "senza plugin" sono:

### 2.1 `JavaClassWrapper` + `AndroidRuntime` (Godot 4.4+, built-in)

Godot 4.4 ha introdotto `JavaClassWrapper`, che permette di creare istanze di classi Java/Kotlin, implementare interfacce e chiamare metodi da GDScript [G14], [G15]. In teoria si può:

1. ottenere l'`Activity` da `Engine.get_singleton("AndroidRuntime").getActivity()`;
2. ottenere `LocationManager` via `getSystemService("location")`;
3. creare un proxy GDScript per `android.location.LocationListener` con `JavaClassWrapper.create_proxy(...)`;
4. chiamare `requestLocationUpdates(...)`.

**Perché non lo raccomando in produzione:**

- il proxy creato da `AndroidRuntimePlugin` invoca `Callable.call(godotObjectID, methodName, args)` **direttamente** dal thread Java che riceve la callback [G16]; `Callable.call` finisce in `nativeCallObject`, che esegue `callable.call()` in modo sincrono, non `call_deferred()` [G17]. Con `LocationListener` la callback arriva sul thread dell'executor/Looper scelto (tipicamente il main thread Android), che **non è il render/script thread di Godot**. Il percorso supportato e thread-safe per un plugin è invece `GodotPlugin.emitSignal(...)`, che fa `godot.runOnRenderThread(...)` [G9].
- `create_proxy` per interfacce è una funzione recente (PR #115498, gennaio 2026), quindi meno collaudata di `emitSignal` [G14], [G16], [G21].
- su desktop/editor `JavaClassWrapper` non esiste: servirebbe comunque un fallback fake GPS [G14].

`JavaClassWrapper` resta utile per uno **spike** rapido (es. leggere `getLastKnownLocation` o verificare i permessi), ma non è la base affidabile per un flusso asincrono continuo. Un plugin nativo che emette segnali è più prevedibile.

### 2.2 GDExtension / JNI manuale

Non necessario: l'API di localizzazione è Java/Android; il plugin v2 è già il bridge JNI supportato e documentato [G4]. Scrivere JNI a mano aggiunge superficie e manutenzione senza vantaggi.

---

## 3. Plugin community: stato, licenza, compatibilità

Ricerca effettuata su GitHub e Godot Asset Library il 2026-10-31. Metadati GitHub via API (stelle, ultimo push, release, `archived`).

| Plugin | Ultima attività / release | Licenza | Godot dichiarato | Play Services | Cosa fa | Valutazione |
|---|---|---|---|---|---|---|
| **KarimIbrahim/Godot-Geolocation-Android** — "Android Geolocation Plugin" su Asset Library (asset 3320, v0.1, 4.3) [P2] | ultimo commit 2024-09-09; release v0.1 2024-09-09 | MIT (LICENSE del template originale) | 4.2+ (v2); Asset Library indica 4.3 | **No**, usa `LocationManager.FUSED_PROVIDER` | lat/lon via `locationUpdate`; wrapper GDScript; nessuna accuracy/altitudine | Il più vicino, ma **fermo da ~2 anni**, API minimale, non testato 4.7 |
| **PraxisMapper/GodotGPSPlugin** [P1] | Release04 2025-03-17; ultimo commit di codice 2025-09-06; **archiviato** su GitHub (rilevato 2026-10-31) | MIT | 4.2.1+ (v2), compila con Godot 4.2.0 | **No**, `LocationManager` con provider `"gps"` | dizionario ricco (lat, lon, accuracy, altitude, speed, bearing, time); setter di intervallo/distanza | **Archiviato**; provider solo GPS (scarso indoor); foreground service solo TODO; non 4.7 |
| **MrSfantaus/GPS-Godot-Android-Plugin** [P3] | release 1.0.0 il 2025-12-29 (stesso giorno del commit) | MIT | 4.2+ (v2), compila con Godot 4.2.0 | **Sì**, `play-services-location:21.0.1` | `FusedLocationProviderClient`, 1 s, last location; stop in pausa | `minSdk 34` (incompatibile con min 26 senza rebuild); 1 stella; dichiara `ACCESS_BACKGROUND_LOCATION` senza servizio; non 4.7 |
| **TheOathMan/Godot-Android-Location-Plugin** [P4] | release v1.0.0 2024-05-15; ultimo commit 2026-10-25 | MIT | 4.5.0 (v2), compileSdk 36 | **Sì**, `play-services-location:21.4.0` | fused + bussola; intervallo 100 ms (10 Hz), min 50 ms | Aggiornato di recente ma **0 stelle**, nessuna release recente, frequenza troppo aggressiva; non 4.7 |
| **Llyfrs/location-tracker-plugin** [P5] | nessuna release; ultimo commit 2026-04-23 | MIT | 4.5.0 (v2) | **Sì**, `play-services-location:21.3.0` | foreground service `location`, DB locale, snapshot distruttivi | Fatto su misura per un altro gioco; API non generale; 0 stelle; non 4.7 |
| **WolfBearGames/Godot-GeolocationPlugin-Android** [P6] | v1.0.0 2022-10-26 | MIT | **Godot 3.5.1** (plugin v1) | n/d | geolocalizzazione Android | **Incompatibile** con Godot 4.x (v1) |
| **cagdasc/godot-location-plugin** [P7] | ultimo commit 2021-06-20 | Apache-2.0 | Godot 3.x | n/d | `LocationManager` | **Incompatibile / abbandonato** |

### 3.1 Cosa manca a tutti

- **Manutenzione attiva**: Praxis è archiviato; Karim è fermo al 2024; gli altri sono progetti personali con 0–1 stelle.
- **Compatibilità 4.7 dichiarata e testata**: nessuno dichiara 4.7; quelli v2 compilano contro Godot 4.2/4.5. La ABI v2 sembra stabile (nessun metodo pubblico rimosso tra `GodotPlugin` 4.2 e 4.7), ma non c'è evidenza di test su 4.7.2.
- **Nessuna dipendenza GMS + dati completi + background**: Karim e Praxis evitano GMS ma sono minimi/archiviati; MrSfantaus, TheOathMan e Llyfrs usano GMS.
- **Permessi corretti su Android 12+**: Karim chiede solo `ACCESS_FINE_LOCATION` con `ActivityCompat.requestPermissions`, mentre Android 12 richiede FINE+COARSE nella stessa richiesta [A2], [P2].
- **Frequenza/qualità controllabili**: Karim espone solo `minTime`/`minDistance`; TheOathMan usa 10 Hz; MrSfantaus ferma gli update in pausa (niente schermo spento).

**Conclusione:** adottare un plugin community significa ereditare un progetto non mantenuto o con dipendenze GMS e limiti funzionali. Per un progetto che deve durare e girare su un dispositivo specifico, il plugin interno è la scelta più difendibile.

---

## 4. Plugin Android v2 interno: architettura e build

### 4.1 Perché v2

Il plugin v2 è l'architettura corrente: libreria Android (AAR) con dipendenza dalla Godot Android library, classe init che estende `GodotPlugin`, manifest con meta-data `org.godotengine.plugin.v2.<Nome>`, packaging tramite `EditorExportPlugin` [G4]. Richiede Godot 4.2+ e Gradle build [G4]. Il template ufficiale consigliato dalla documentazione è `m4gr3d/Godot-Android-Plugin-Template` (MIT, mantenuto; ultimo commit 2025-12-11) [G5].

Un plugin v2 può usare API Android, librerie Kotlin/Java e JNI; non serve scrivere codice nativo [G4].

### 4.2 Configurazione consigliata

| Voce | Valore | Fonte |
|---|---|---|
| Godot Android library | `org.godotengine:godot:4.7.2.stable` | [G20] |
| `compileSdk` | 36 | [G10] |
| `targetSdk` | 36 | [G10], [G11] |
| `minSdk` plugin | 26 (allineato al progetto) | `map.md` |
| JDK | 17 | [G10] |
| Kotlin | 2.1.21 (o quella del template, purché compatibile) | [G10] |
| AGP | 8.6.1 | [G10] |
| Gradle build | obbligatoria per i plugin v2 | [G4] |

Il template va aggiornato: la sua versione corrente usa `godot:4.5.1.stable` e `compileSdk 36` [G5]; basta cambiare la dipendenza a `4.7.2.stable` e allineare `minSdk`/Kotlin.

### 4.3 Threading: la regola d'oro

`LocationListener` viene chiamato su un thread Android (main executor/Looper). **Non chiamare GDScript direttamente da quel thread.** Il plugin deve solo costruire un `Dictionary` e chiamare `emitSignal(...)`: `GodotPlugin.emitSignal` valida il segnale e fa `godot.runOnRenderThread(() -> nativeEmitSignal(...))` [G9]. Questo è il percorso supportato per consegnare dati al main loop di Godot.

Questo è anche il motivo per cui un plugin nativo è preferibile a un proxy `JavaClassWrapper` per callback asincrone: il proxy usa `Callable.call` immediato [G16], [G17], mentre `emitSignal` fa il marshalling sul render thread [G9].

### 4.4 Contratto dati minimo

Un solo segnale `location_fix(Dictionary)` con:

| Chiave | Tipo | Note |
|---|---|---|
| `latitude`, `longitude` | `float` | WGS84 |
| `accuracy` | `float` | raggio orizzontale in metri al 68° percentile [A11] |
| `altitude` | `float` | metri sopra WGS84 |
| `speed` | `float` | m/s |
| `bearing` | `float` | gradi |
| `time_ms` | `int` | `Location.getTime()` (wall clock) |
| `elapsed_ns` | `int` | `Location.getElapsedRealtimeNanos()`, monotono, per l'età del fix [A11] |
| `is_mock` | `bool` | `Location.isMock()` su API 31+, altrimenti `isFromMockProvider()` [A11] |

Un secondo segnale `location_error(String)` per: permesso mancante, provider disabilitato, servizio location spento, timeout.

---

## 5. Permessi runtime

### 5.1 Cosa dichiarare

Nel manifest del plugin (o nell'export preset Android, sezione Permissions):

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

Non dichiarare `ACCESS_BACKGROUND_LOCATION` per la vertical slice: non serve se l'app è in foreground e introduce un flusso di permesso in più (Android 11+ manda l'utente nella pagina impostazioni) [A3], [A5]. La distribuzione via APK rende irrilevante la policy Play, ma non i limiti di sistema.

### 5.2 Come richiederli

GDScript:

```gdscript
var already_granted := OS.request_permissions()   # true se già tutti concessi
# se false: collegare get_tree().on_request_permissions_result e attendere FINE
```

`OS.request_permissions()` richiede **tutti i permessi dangerous dichiarati nel manifest mergiato**, non solo quelli selezionati nell'export preset [G7]. Quindi:

- tenere il manifest minimale (solo COARSE+FINE), altrimenti verranno chieste anche fotocamera, notifiche, ecc.;
- il manifest del plugin AAR viene mergiato nel manifest dell'app dal Gradle manifest merger [A12]; il plugin non deve chiamare `ActivityCompat.requestPermissions` da solo.

Il risultato arriva per ogni permesso sul segnale `on_request_permissions_result(permission: String, granted: bool)` di `MainLoop`/`SceneTree` [G6]; Godot inoltra il risultato anche ai plugin (`onMainRequestPermissionsResult`) [G8].

### 5.3 Android 12+: preciso vs approssimativo

Su Android 12+ l'utente può concedere solo la posizione **approssimativa** anche se l'app ha chiesto `ACCESS_FINE_LOCATION`. La documentazione Android raccomanda di chiedere **FINE e COARSE insieme**, perché chiedere solo FINE può essere ignorato su alcune release di Android 12 [A2].

| Scelta utente | Permessi concessi | Conseguenza per il gioco |
|---|---|---|
| Preciso | FINE + COARSE | GPS utilizzabile |
| Approssimativo | solo COARSE | area di ~3 km²: del tutto insufficiente per l'avatar; mostrare spiegazione e chiedere upgrade |
| Nega | nessuno | nessun fix; mostrare UI di spiegazione, non crashare |

Attenzione: se l'utente **downgrada** da preciso ad approssimativo, il sistema **riavvia il processo** dell'app [A2]. Il gioco deve gestire il riavvio e non assumere che il permesso resti preciso.

### 5.4 Permesso negato / "non chiedere più"

- `OS.request_permissions()` restituisce `false` anche quando il dialog è stato appena mostrato; non è un "no".
- Dopo un diniego definitivo, il dialog non riappare: mostrare una spiegazione e un pulsante che apre le impostazioni dell'app. Per la vertical slice basta un messaggio chiaro e un pulsante "Riprova"; non serve un flusso complesso.
- Su Android 12+ l'utente può concedere solo COARSE: trattare questo caso come "GPS insufficiente", non come "permesso assente".

### 5.5 Location services spenti

Prima di avviare gli update, controllare `LocationManager.isLocationEnabled` (API 28+) e `isProviderEnabled(provider)` [A8]. Se i servizi sono spenti, il plugin deve emettere `location_error("location_disabled")`; GDScript mostra un pulsante per aprire le impostazioni di localizzazione.

---

## 6. Frequenza, precisione, filtro

### 6.1 Provider

| API | Provider | Uso |
|---|---|---|
| Android 12+ (API 31+) | `LocationManager.FUSED_PROVIDER` (`"fused"`) | può combinare GNSS, Wi-Fi e cella; miglior compromesso [A8] |
| API 26–30 | `GPS_PROVIDER`, poi `NETWORK_PROVIDER` | fallback; GPS preciso outdoor, network approssimativo |
| avvio (tutte le API) | `getLastKnownLocation` | ultimo fix noto per partire subito [A8] |
| API 30+ | `getCurrentLocation` | fix fresco su richiesta; non disponibile su API 26–29 [A8] |

Il provider fused di **piattaforma** è disponibile da Android 12 e non richiede Google Play Services [A8]. È la ragione principale per cui non serve `play-services-location` sul Fairphone 6 / Android 16. Se `FUSED_PROVIDER` non è presente o disabilitato, il plugin deve degradare a GPS/NETWORK.

**Piano B (solo se necessario):** `FusedLocationProviderClient` di Google Play Services è mantenuto e spesso offre fix migliori indoor e una gestione batteria più fine, ma aggiunge la dipendenza `play-services-location`, richiede GMS e non cambia le regole di permesso/background [A10]. Non è necessario per la slice e aumenta il lock-in; valutarlo solo se la precisione di piattaforma si rivelasse insufficiente sul campo.

### 6.2 Parametri consigliati

| Parametro | Valore | Motivazione |
|---|---|---|
| intervallo richiesto | 1000 ms | 1 Hz è sufficiente per un avatar che cammina (≈1,4 m/s); 5–10 Hz consumano e producono jitter |
| intervallo minimo | 500 ms | consente un fix extra se il provider è pronto, senza martellare |
| distanza minima | 1.0 m | evita update da fermo; mantiene il fix precedente |
| qualità | `QUALITY_HIGH_ACCURACY` | il gioco ha bisogno della precisione; accettare il costo batteria |
| batching | 0 (nessuno) | in foreground non serve; il batching è per il background [A14] |

Su API 31+ usare `LocationRequest.Builder(intervalMs)` con `setQuality`, `setMinUpdateIntervalMillis`, `setMinUpdateDistanceMeters` [A9]. Su API 26–30 usare l'overload `requestLocationUpdates(provider, minTimeMs, minDistanceM, listener, looper)` [A8].

### 6.3 Precisione attesa e filtri

Android definisce `Location.getAccuracy()` come raggio orizzontale al 68° percentile: c'è il 68% di probabilità che la posizione vera sia dentro quel cerchio [A11]. La documentazione sui permessi indica che la posizione precisa è "di solito entro ~50 m, a volte entro pochi metri" [A1].

Filtri minimi lato GDScript/plugin:

1. **Età**: scartare fix con `now_elapsed_ns - fix.elapsed_ns > 2 s` (specie su resume; Android può consegnare fix cachati non più vecchi dell'intervallo [A8]).
2. **Accuratezza**: se `accuracy > 30 m`, non muovere l'avatar (o muoverlo molto lentamente) e mostrare "GPS debole"; se `> 50 m`, ignorare il fix.
3. **Velocità plausibile**: se lo spostamento implica > 3 m/s (camminata veloce), clampare o scartare; un salto GPS in città non deve teletrasportare l'avatar.
4. **Smoothing**: media pesata/esponenziale tra fix validi; interpolare tra un fix e l'altro per l'animazione, non alzare la frequenza GPS.
5. **Mock**: `is_mock` va mostrato nell'HUD di debug; non è una misura di sicurezza, ma aiuta a distinguere fake GPS da GPS reale [A11].

### 6.4 Batteria

- 1 Hz con `HIGH_ACCURACY` è il costo maggiore; fermare gli update quando l'app è in pausa e quando il gioco non è in primo piano.
- `setMinUpdateDistanceMeters(1.0)` riduce gli update da fermo.
- Non usare `setMaxUpdateDelayMillis` in foreground: il batching aggiunge latenza senza beneficio [A14].
- Il sistema tiene un wakelock durante le callback di localizzazione "per un periodo, non indefinitamente" [A8]: non farci affidamento per il background.

---

## 7. Schermo spento e background

### 7.1 Cosa succede davvero

- Quando l'Activity va in pausa/stop (schermo spento, app in background), Godot invia `NOTIFICATION_APPLICATION_PAUSED` al main loop [G6] e mette in pausa il render thread: `GodotGLRenderView.onActivityPaused()` chiama `GodotLib.onRendererPaused()`, e `onActivityStopped()` chiama `pauseGLThread()` [G18]. In pratica `_process` e le callback GDScript **non girano** mentre lo schermo è spento.
- Un `LocationListener` nativo può continuare a ricevere fix se il processo resta vivo, ma i segnali del plugin vengono consegnati al render thread e saranno processati solo al resume [G9]; senza un buffer nativo i fix in background vanno persi.
- Senza foreground service, Android 8+ limita gli aggiornamenti in background a **pochi fix all'ora** [A5]; il client fused senza `ACCESS_BACKGROUND_LOCATION` o FGS non riceve affatto posizioni in background [A10].

### 7.2 Scelta per la vertical slice: foreground + schermo acceso

Per un gioco in stile Pokémon GO la sessione è tipicamente a schermo acceso. La soluzione più semplice e robusta per la slice:

```gdscript
func _ready() -> void:
    DisplayServer.screen_set_keep_on(true)
```

`DisplayServer.screen_set_keep_on(true)` è implementato su Android e imposta il keep-screen-on nativo [G12], [G13]. Insieme allo stop degli update in `NOTIFICATION_APPLICATION_PAUSED`, evita di promettere un background che non c'è.

### 7.3 Se e quando serve il background vero

Servirà un foreground service con tipo `location`, non un semplice listener:

1. Manifest del plugin:
   ```xml
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
   <service
       android:name=".GpsForegroundService"
       android:foregroundServiceType="location"
       android:exported="false" />
   ```
   Da Android 14 (API 34) il tipo e il permesso `FOREGROUND_SERVICE_LOCATION` sono obbligatori [A6].
2. Avviare il service **mentre l'app è visibile**: un FGS di tipo location non può partire dal background senza `ACCESS_BACKGROUND_LOCATION` [A6].
3. Mostrare la notifica persistente; su Android 13+ `POST_NOTIFICATIONS` è consigliato per la notifica (non blocca il FGS, ma senza di essa la notifica può non apparire).
4. Bufferizzare i fix **in Kotlin** (ring buffer o SQLite) e esporre `drain_fixes()`; GDScript li consuma al resume. Non affidarsi a callback GDScript in background.
5. Testare Doze/App Standby e i risparmi energetici OEM: un FGS mantiene l'accesso alla posizione anche a schermo spento [A1], ma Doze può sospendere rete/CPU e alcuni produttori killano comunque i processi [A7]. Non è un "set and forget".

**Non serve `ACCESS_BACKGROUND_LOCATION`** se il FGS parte sempre in foreground. Richiederlo comunque complica l'UX (Android 11+ rimanda alle impostazioni) e non è necessario per la slice [A3].

---

## 8. Schema minimo GDScript ↔ Android

### 8.1 Struttura file

```text
android-plugin/                         # fuori da res:// (progetto Gradle)
  build.gradle.kts
  settings.gradle.kts
  plugin/
    build.gradle.kts
    src/main/AndroidManifest.xml
    src/main/java/com/example/gps/GpsPlugin.kt
    export_scripts_template/export_plugin.gd
    export_scripts_template/plugin.cfg

addons/gps/                             # dentro res://
  plugin.cfg
  export_plugin.gd
  bin/debug/gps-debug.aar
  bin/release/gps-release.aar

scripts/gps_source.gd                   # wrapper GDScript + fallback fake
```

Il plugin AAR va copiato in `addons/gps/bin/{debug,release}`; l'`EditorExportPlugin` restituisce i path relativi ad `addons/` [G4], [G5].

### 8.2 Manifest del plugin

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

    <application>
        <meta-data
            android:name="org.godotengine.plugin.v2.GpsPlugin"
            android:value="com.example.gps.GpsPlugin" />
    </application>
</manifest>
```

### 8.3 Kotlin minimo

```kotlin
package com.example.gps

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.location.LocationRequest
import android.os.Build
import android.os.Bundle
import android.os.Looper
import android.view.View
import org.godotengine.godot.Dictionary
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class GpsPlugin(godot: Godot) : GodotPlugin(godot), LocationListener {
    private val fixSignal = SignalInfo("location_fix", Dictionary::class.java)
    private val errorSignal = SignalInfo("location_error", String::class.java)
    private var manager: LocationManager? = null
    private var lastFix = Dictionary()

    override fun getPluginName() = "GpsPlugin"
    override fun getPluginSignals() = setOf(fixSignal, errorSignal)

    override fun onMainCreate(activity: Activity?): View? {
        manager = activity?.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        return super.onMainCreate(activity)
    }

    private fun hasLocationPermission(): Boolean {
        val act = activity ?: return false
        return act.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            act.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun chooseProvider(m: LocationManager): String? {
        val candidates = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(
                LocationManager.FUSED_PROVIDER,
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER
            )
        } else {
            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
        }
        return candidates.firstOrNull {
            runCatching { m.isProviderEnabled(it) }.getOrDefault(false)
        }
    }

    @UsedByGodot
    fun start_updates(intervalMs: Long, minIntervalMs: Long, minDistanceM: Float): Boolean {
        val m = manager ?: return false
        val act = activity ?: return false
        if (!hasLocationPermission()) {
            emitSignal(errorSignal, "missing_permission")
            return false
        }
        val p = chooseProvider(m)
        if (p == null) {
            emitSignal(errorSignal, "no_provider")
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val request = LocationRequest.Builder(intervalMs)
                .setQuality(LocationRequest.QUALITY_HIGH_ACCURACY)
                .setMinUpdateIntervalMillis(minIntervalMs)
                .setMinUpdateDistanceMeters(minDistanceM)
                .build()
            m.requestLocationUpdates(p, request, act.mainExecutor, this)
        } else {
            m.requestLocationUpdates(p, intervalMs, minDistanceM, this, Looper.getMainLooper())
        }
        return true
    }

    @UsedByGodot
    fun stop_updates() {
        manager?.removeUpdates(this)
    }

    @UsedByGodot
    fun get_last_fix(): Dictionary = lastFix

    @Suppress("DEPRECATION")
    override fun onLocationChanged(location: Location) {
        val d = Dictionary()
        d["latitude"] = location.latitude
        d["longitude"] = location.longitude
        d["accuracy"] = location.accuracy.toDouble()
        d["altitude"] = location.altitude.toDouble()
        d["speed"] = location.speed.toDouble()
        d["bearing"] = location.bearing.toDouble()
        d["time_ms"] = location.time
        d["elapsed_ns"] = location.elapsedRealtimeNanos
        d["is_mock"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            location.isMock
        } else {
            location.isFromMockProvider
        }
        lastFix = d
        emitSignal(fixSignal, d)          // marshalling sul render thread
    }

    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {
        emitSignal(errorSignal, "provider_disabled:$provider")
    }
}
```

Note:

- `emitSignal` è l'unico punto che tocca Godot; non chiamare GDScript dal listener [G9].
- `LocationListener` va implementata con tutti i metodi per compatibilità con API 26–29 (su API 30+ alcuni sono default) [A8].
- su API < 31, isolare il codice che referenzia `LocationRequest`/`FUSED_PROVIDER` in un metodo `@RequiresApi(Build.VERSION_CODES.S)` chiamato solo dentro il check di versione, per evitare problemi di verifica della classe su dispositivi vecchi.
- `get_last_fix()` serve per ripartire subito al resume senza aspettare il primo fix.

### 8.4 `export_plugin.gd` minimo

```gdscript
@tool
extends EditorPlugin

var _export_plugin: AndroidExportPlugin

func _enter_tree() -> void:
    _export_plugin = AndroidExportPlugin.new()
    add_export_plugin(_export_plugin)

func _exit_tree() -> void:
    remove_export_plugin(_export_plugin)
    _export_plugin = null

class AndroidExportPlugin extends EditorExportPlugin:
    func _supports_platform(platform) -> bool:
        return platform is EditorExportPlatformAndroid

    func _get_android_libraries(platform, debug) -> PackedStringArray:
        var kind := "debug" if debug else "release"
        return PackedStringArray(["gps/bin/%s/gps-%s.aar" % [kind, kind]])

    func _get_name() -> String:
        return "GpsPlugin"
```

### 8.5 Wrapper GDScript minimo

```gdscript
extends Node
class_name GpsSource

signal fix(data: Dictionary)
signal error(message: String)
signal permission(granted: bool)

const PLUGIN_NAME := "GpsPlugin"
const FINE := "android.permission.ACCESS_FINE_LOCATION"

var _gps: Object
var _last: Dictionary = {}
var _want_running := false

func _ready() -> void:
    if Engine.has_singleton(PLUGIN_NAME):
        _gps = Engine.get_singleton(PLUGIN_NAME)
        _gps.location_fix.connect(_on_fix)
        _gps.location_error.connect(_on_error)
        get_tree().on_request_permissions_result.connect(_on_permission_result)
    # else: desktop/editor -> usare FakeGpsSource (fuori scope di questo ticket)

func start() -> void:
    _want_running = true
    if _gps == null:
        return
    if _has_fine():
        _start_native()
    else:
        # Chiamare da un pulsante, dopo una spiegazione: non al primo frame.
        OS.request_permissions()

func stop() -> void:
    _want_running = false
    if _gps != null:
        _gps.stop_updates()

func _has_fine() -> bool:
    return OS.get_granted_permissions().has(FINE)

func _on_permission_result(permission: String, granted: bool) -> void:
    if permission == FINE:
        if granted:
            _start_native()
        else:
            emit_signal("permission", false)

func _start_native() -> void:
    var ok: bool = _gps.start_updates(1000, 500, 1.0)
    emit_signal("permission", ok)
    if not ok:
        emit_signal("error", "start_failed")

func _on_fix(data: Dictionary) -> void:
    _last = data
    emit_signal("fix", data)

func _on_error(message: String) -> void:
    emit_signal("error", message)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED:
        if _gps != null:
            _gps.stop_updates()
    elif what == NOTIFICATION_APPLICATION_RESUMED:
        if _want_running and _gps != null and _has_fine():
            _start_native()
```

### 8.6 Sequenza permessi

```text
Utente preme "Attiva GPS"
  -> GDScript: OS.request_permissions()
  -> Android: dialog FINE+COARSE (o solo COARSE se l'utente sceglie approx)
  -> Godot: on_request_permissions_result(permission, granted)
  -> GDScript: se FINE granted -> _gps.start_updates(1000, 500, 1.0)
  -> Kotlin: checkSelfPermission; chooseProvider; requestLocationUpdates
  -> Kotlin: onLocationChanged -> Dictionary -> emitSignal("location_fix")
  -> Godot: segnale su render thread -> GDScript aggiorna l'avatar
```

### 8.7 Checklist di test su Fairphone 6

- [ ] Permesso concesso "Preciso" → fix a 1 Hz, accuracy in HUD.
- [ ] Permesso "Approssimativo" → nessun movimento o movimento bloccato + messaggio.
- [ ] Permesso negato → nessun crash, messaggio e pulsante riprova.
- [ ] Permesso revocato dalle impostazioni mentre il gioco è in pausa → al resume nessun crash; il wrapper rileva `_has_fine() == false` e ripropone la spiegazione/richiesta.
- [ ] Servizi di localizzazione spenti → `location_disabled`.
- [ ] Schermo spento con keep-screen-on attivo → il gioco resta attivo e i fix continuano.
- [ ] App in background senza FGS → update fermati, nessun fix "vecchio" usato al resume.
- [ ] Fake GPS / mock location → `is_mock == true` nell'HUD.
- [ ] Camminata di 10 minuti in ambiente urbano → nessun teletrasporto, accuracy e velocità plausibili.
- [ ] Build release firmata, installata via APK (non debug), Gradle build attiva.

---

## 9. Rischi e mitigazioni

| # | Rischio | Probabilità / impatto | Mitigazione |
|---|---|---|---|
| R1 | Manutenzione del plugin interno (Kotlin/Gradle) | Media / Media | partire dal template ufficiale, codice ~200 righe, dipendenza solo Godot AAR, pin versioni |
| R2 | ABI/API Godot cambia in un upgrade | Bassa / Alta | ricompilare contro `4.7.2.stable`; testare su device a ogni upgrade; la v2 non ha rimosso metodi tra 4.2 e 4.7, ma non è una garanzia |
| R3 | `FUSED_PROVIDER` assente o disabilitato | Bassa / Media | fallback GPS → NETWORK; esporre `no_provider` |
| R4 | Permesso approx/negato | Alta / Alta | UX dedicata; check FINE; spiegazione; impostazioni |
| R5 | Schermo spento/background non supportati | Alta / Media | keep-screen-on per la slice; FGS + buffer nativo in un ticket separato |
| R6 | Jitter/teletrasporti GPS in città | Alta / Media | filtri età/accuracy/velocità, smoothing, interpolazione |
| R7 | Threading: callback Java → GDScript | Media / Alta | usare solo `emitSignal` (render thread); non `Callable.call` da listener; niente `JavaClassWrapper` per il flusso continuo |
| R8 | Doze/OEM battery killer in background | Media / Alta | non promettere background; test reale; FGS + notifica; accettare limiti |
| R9 | Mock location / cheating | Bassa / Bassa | `is_mock` in HUD; non è sicurezza |
| R10 | Target SDK 36 e behavior changes Android 16 | Media / Bassa | test edge-to-edge/orientamento; il GPS non cambia; Godot 4.7.2 è già target 36 [G10], [A13] |

---

## 10. Decisione

**Adottare un plugin Android v2 interno `GpsPlugin`** con:

1. `LocationManager` di piattaforma, `FUSED_PROVIDER` su API 31+, fallback GPS/NETWORK.
2. Manifest con solo `ACCESS_COARSE_LOCATION` + `ACCESS_FINE_LOCATION`; richiesta runtime via `OS.request_permissions()`.
3. Segnale `location_fix(Dictionary)` emesso con `emitSignal` (render thread).
4. 1 Hz / min 500 ms / min 1 m / alta precisione; filtri lato GDScript.
5. Vertical slice foreground-only + `DisplayServer.screen_set_keep_on(true)`; stop in pausa.
6. Background FGS `location` + buffer nativo solo se e quando il prodotto lo richiederà.

**Perché non un plugin community:** nessuno è contemporaneamente mantenuto, testato su 4.7, senza GMS e con dati/permessi/background adeguati. I due senza GMS sono uno archiviato (Praxis) e uno fermo al 2024 (Karim); gli altri dipendono da Play Services e hanno minSdk/API o frequenze problematiche.

**Cosa farebbe cambiare decisione:** la comparsa di un plugin community con release recente, test dichiarato su 4.7, licenza permissiva, nessuna dipendenza GMS, accuracy/altitudine/velocità e foreground service documentato. Oggi non esiste.

**Prossimi passi suggeriti (fuori da questo ticket):**

1. Creare il progetto Gradle dal template ufficiale, dipendenza `godot:4.7.2.stable`, `compileSdk/targetSdk 36`, `minSdk 26`.
2. Implementare `GpsPlugin` e il wrapper GDScript con fake source desktop.
3. Export debug, test su Fairphone 6 con i casi della checklist.
4. Solo dopo: valutare FGS/background in un ticket dedicato.

---

## Fonti

Tutte le fonti sono state consultate il **2026-10-31**. I link a GitHub puntano ai file al tag `4.7.2-stable` o al repository corrente.

### Godot Engine

- **[G1]** Godot 4.7 — `OS` class reference (permessi; nessuna API di localizzazione): https://docs.godotengine.org/en/stable/classes/class_os.html
- **[G2]** Godot 4.7 — `Input` class reference: https://docs.godotengine.org/en/stable/classes/class_input.html
- **[G3]** Godot PR #47702 "Add GPS functionality for Android" (chiusa senza merge): https://github.com/godotengine/godot/pull/47702
- **[G4]** Godot 4.7 — "Godot Android plugins" (v2, `@UsedByGodot`, segnali, packaging, Gradle): https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html
- **[G5]** Template ufficiale Godot Android Plugin (MIT, ultimo commit 2025-12-11): https://github.com/m4gr3d/Godot-Android-Plugin-Template
- **[G6]** Godot 4.7 — `MainLoop` (segnale `on_request_permissions_result`, `NOTIFICATION_APPLICATION_PAUSED/RESUMED`): https://docs.godotengine.org/en/stable/classes/class_mainloop.html
- **[G7]** Godot 4.7.2 — `PermissionsUtil.java` (`requestManifestPermissions` richiede tutti i permessi dangerous del manifest): https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/lib/src/main/java/org/godotengine/godot/utils/PermissionsUtil.java
- **[G8]** Godot 4.7.2 — `Godot.kt` (`onRequestPermissionsResult`, inoltro ai plugin e a `GodotLib`): https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/lib/src/main/java/org/godotengine/godot/Godot.kt
- **[G9]** Godot 4.7.2 — `GodotPlugin.java` (`emitSignal` → `runOnRenderThread`): https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/lib/src/main/java/org/godotengine/godot/plugin/GodotPlugin.java
- **[G10]** Godot 4.7.2 — `config.gradle` (compileSdk 36, minSdk 24, targetSdk 36, JDK 17, Kotlin 2.1.21, AGP 8.6.1): https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/app/config.gradle
- **[G11]** Godot 4.7.2 — `export_plugin.cpp` (default min/target SDK 24/36): https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/export/export_plugin.cpp
- **[G12]** Godot 4.7 — `DisplayServer` (`screen_set_keep_on`): https://docs.godotengine.org/en/stable/classes/class_displayserver.html
- **[G13]** Godot 4.7.2 — `display_server_android.cpp` (implementazione Android di keep-screen-on): https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/display_server_android.cpp
- **[G14]** Godot 4.7 — `JavaClassWrapper` (solo Android, `create_proxy`, `create_sam_callback`): https://docs.godotengine.org/en/stable/classes/class_javaclasswrapper.html
- **[G15]** Godot 4.7 — "Integrating with Android APIs" (JavaClassWrapper + AndroidRuntime): https://docs.godotengine.org/en/stable/tutorials/platform/android/javaclasswrapper_and_androidruntimeplugin.html
- **[G16]** Godot 4.7.2 — `AndroidRuntimePlugin.kt` (proxy → `Callable.call` immediato): https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/lib/src/main/java/org/godotengine/godot/plugin/AndroidRuntimePlugin.kt
- **[G17]** Godot 4.7.2 — `callable_jni.cpp` (`nativeCallObject` immediato vs `call_deferred`): https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/variant/callable_jni.cpp
- **[G18]** Godot 4.7.2 — `GodotGLRenderView.java` (`onActivityPaused`, `onActivityStopped` → pausa render thread): https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/lib/src/main/java/org/godotengine/godot/GodotGLRenderView.java
- **[G19]** Godot 4.7.2-stable release: https://github.com/godotengine/godot/releases/tag/4.7.2-stable
- **[G20]** Maven Central — `org.godotengine:godot:4.7.2.stable`: https://central.sonatype.com/artifact/org.godotengine/godot/4.7.2.stable
- **[G21]** Godot PR #115498 "Android: Allow implementing java interfaces from GDScript" (proxy per interfacce): https://github.com/godotengine/godot/pull/115498
- **[G22]** Godot 4.7 — class index (nessuna classe `Geolocation`/`Location`): https://docs.godotengine.org/en/stable/classes/index.html

### Android Developers

- **[A1]** Request location permissions (foreground/background, FGS, accuratezza): https://developer.android.com/develop/sensors-and-location/location/permissions
- **[A2]** Request location access at runtime (preciso vs approssimativo, FINE+COARSE insieme, riavvio processo): https://developer.android.com/develop/sensors-and-location/location/permissions/runtime
- **[A3]** Request background location (Android 11+ impostazioni, policy): https://developer.android.com/develop/sensors-and-location/location/permissions/background
- **[A4]** Request location updates (fused provider, callback): https://developer.android.com/develop/sensors-and-location/location/request-updates
- **[A5]** Access location in the background (limite "pochi fix all'ora" da Android 8): https://developer.android.com/develop/sensors-and-location/location/background
- **[A6]** Foreground service types — `location` (Android 14+, `FOREGROUND_SERVICE_LOCATION`, start da background): https://developer.android.com/develop/background-work/services/fgs/service-types#location
- **[A7]** Doze and App Standby (restrizioni background, wake lock, rete): https://developer.android.com/training/monitoring-device-state/doze-standby
- **[A8]** `LocationManager` reference (`FUSED_PROVIDER` API 31, `requestLocationUpdates`, wakelock, fix cachati): https://developer.android.com/reference/android/location/LocationManager
- **[A9]** `LocationRequest.Builder` reference (intervallo, min interval, min distance, qualità): https://developer.android.com/reference/android/location/LocationRequest.Builder
- **[A10]** `FusedLocationProviderClient` reference (coarse offuscato/limitato, background senza FGS): https://developers.google.com/android/reference/com/google/android/gms/location/FusedLocationProviderClient
- **[A11]** `Location` reference (`getAccuracy` 68° percentile, `getElapsedRealtimeNanos`, `isMock`): https://developer.android.com/reference/android/location/Location
- **[A12]** Android manifest merging (manifest delle librerie mergiato nell'app): https://developer.android.com/build/manage-manifests
- **[A13]** Android 16 behavior changes (target SDK 36): https://developer.android.com/about/versions/16/behavior-changes-16
- **[A14]** Optimize location use for battery life (timeout, batching, passive updates): https://developer.android.com/develop/sensors-and-location/location/battery/optimize

### Plugin community

- **[P1]** PraxisMapper/GodotGPSPlugin (MIT, archiviato; `LocationManager` provider `"gps"`, TODO FGS): https://github.com/PraxisMapper/GodotGPSPlugin
- **[P2]** KarimIbrahim/Godot-Geolocation-Android (MIT; `FUSED_PROVIDER`, solo lat/lon; Asset Library asset 3320): https://github.com/KarimIbrahim/Godot-Geolocation-Android
- **[P3]** MrSfantaus/GPS-Godot-Android-Plugin (MIT; GMS, minSdk 34, stop in pausa): https://github.com/MrSfantaus/GPS-Godot-Android-Plugin
- **[P4]** TheOathMan/Godot-Android-Location-Plugin (MIT; GMS, compileSdk 36, 100 ms): https://github.com/TheOathMan/Godot-Android-Location-Plugin
- **[P5]** Llyfrs/location-tracker-plugin (MIT; GMS, foreground service `location`, specifico per Path Village): https://github.com/Llyfrs/location-tracker-plugin
- **[P6]** WolfBearGames/Godot-GeolocationPlugin-Android (MIT; Godot 3.5.1, plugin v1): https://github.com/WolfBearGames/Godot-GeolocationPlugin-Android
- **[P7]** cagdasc/godot-location-plugin (Apache-2.0; Godot 3, ultimo commit 2021): https://github.com/cagdasc/godot-location-plugin

### Metadati

- GitHub REST API per stelle, release, ultimo commit, `archived`, licenza: `https://api.github.com/repos/<owner>/<repo>` (consultata 2026-10-31).
- Godot Asset Library, ricerca "geolocation" / asset 3320: https://godotengine.org/asset-library/asset/3320
