# Avatar 3D della slice: asset, licenza e piano di import

- Ticket: `06-avatar-asset`
- Data: 31 ottobre 2026
- Stato: risolto
- Decisione: **Quaternius — Ultimate Modular Men Pack (feb 2022), personaggio `Casual_Male`** (variante `Casual_Female` disponibile), licenza **CC0 1.0**, formato **glTF**, **24 animazioni** incluse, altezza **1,858 m**, **5.776 triangoli**, **1,43 MB** il GLB, materiali flat senza texture.

## Sintesi

L'avatar della slice deve essere un umano low-poly credibile in una città contemporanea, non un guerriero fantasy. Il pack **Ultimate Modular Men** di Quaternius è il candidato che meglio combina:

- licenza CC0 verificata nel `License.txt` del pack;
- personaggi moderni (casual, worker, suit, punk, SWAT, astronauta, ecc.);
- **24 clip già incluse**, tra cui `Idle`, `Idle_Neutral`, `Walk`, `Run`;
- **glTF nativo**: un GLB self-contained (o `.gltf` + `.bin`), import diretto in Godot 4.7;
- scala umana corretta (**1,858 m**) e origine ai piedi;
- budget mobile contenuto (**5.776 tris**, 9 materiali flat, nessuna texture).

KayKit Adventurers è CC0 e ha un ecosistema di animazioni superiore, ma è **chibi-fantasy** (knight, mage, ranger): fuori contesto per una mappa urbana. Mixamo è **non CC0**, richiede account Adobe e conversione FBX→glTF, ed è realistico. Universal Base Characters + Universal Animation Library è l'upgrade di qualità, ma è sovradimensionato per la slice (13k tris medi, 122 MB lo standard free, retargeting). Kenney Mini Characters è CC0 ma mini/chibi.

## 1. Criteri di valutazione

1. **Licenza verificabile alla fonte**: CC0 preferito; no licenze ambigue o redistribuzione vietata.
2. **Animazioni incluse**: almeno idle e walk loopabili; run opzionale.
3. **Formato**: glTF 2.0 nativo, import diretto in Godot 4.7 senza conversioni.
4. **Budget mobile**: pochi triangoli, pochi materiali, nessuna texture grande.
5. **Scala**: 1 unità = 1 metro (preferenza del progetto, ticket 04), altezza umana 1,7–1,9 m.
6. **Stile**: low-poly coerente con edifici OSM estrusi; silhouette leggibile a 15–25 m.
7. **Costo di integrazione**: un file, poche impostazioni, nessun retargeting.

## 2. Confronto dei candidati

| Candidato | Licenza effettiva | Formato | Animazioni | Dimensione | Stile / fit urbano | Esito |
|---|---|---|---|---|---|---|
| **Quaternius Ultimate Modular Men (2022)** | **CC0 1.0** (`License.txt` del pack) [S3] | glTF (cartella ufficiale) [S2] | **24** incluse [S1] | **1,43 MB** per GLB [S7] | Umano moderno low-poly, flat color; **ottimo** | **Scelto** |
| KayKit Adventurers + Character Animations | CC0 1.0 [S8][S10] | glTF + FBX [S8] | basiche incluse + 133/161 extra [S10][S11] | 12 MB + 14 MB [S9][S11] | Chibi fantasy (knight/mage); **fuori contesto** | Fallback |
| Quaternius Universal Base Characters + UAL | CC0 (pagina) [S21][S22] | glTF/GLB, FBX, Blend | 45 free (UAL std); 120+ totali [S22] | 122 MB + 15 MB [S21][S22] | Umano stilizzato, 13k tris; **sovradimensionato** | Upgrade futuro |
| Mixamo | Adobe, royalty-free ma **non CC0** [S12][S13] | FBX/OBJ; **no glTF** [S14][S15] | molte | servizio web | Realistico; **stile sbagliato** | Scartato |
| Kenney Mini Characters | CC0 [S23] | n/d | animation [S23] | 25 file [S23] | Mini/chibi; **troppo toy** | Scartato |
| Quaternius Ultimate Animated Character Pack (2019) | CC0 [S24] | glTF [S24] | molte (non dichiarate) | 52 modelli | Moderno + fantasy; alternativa per NPC | Non necessario |

## 3. Analisi dei candidati

### 3.1 Quaternius Ultimate Modular Men — scelto

La pagina ufficiale dichiara **11 personaggi**, **24 animazioni**, formati **FBX, OBJ, glTF e Blend**, licenza **CC0** [S1]. La cartella ufficiale su Google Drive contiene le sottocartelle `All together`, `Humanoid Rig`, `Individual Characters`, `Separate Skeletal Meshes and Animations`, oltre a `License.txt` [S2]. Il personaggio scelto è:

```
Individual Characters/glTF/Casual_Male.gltf
```

Link diretto del file: <https://drive.google.com/file/d/1rrj82IYNaSWj5ySxR6fW9oojyHFiW7_r/view> [S2].

La pagina ufficiale mostra il badge “FBX / OBJ / Blend”, ma il testo della descrizione e la cartella Drive includono **glTF**; la verifica è stata fatta sulla cartella `Individual Characters/glTF`, non solo sul badge [S1][S2].

**Perché è il migliore per la slice**

- È un **umano moderno in abiti casual** (maglietta, jeans, scarpe): coerente con una città contemporanea e con edifici OSM low-poly, molto più di un cavaliere o di un mago.
- **24 clip già dentro il personaggio**, quindi non serve scaricare un secondo pack di animazioni né fare retargeting per idle/walk.
- **glTF** con un solo personaggio per file (GLB self-contained o `.gltf` + `.bin`): import diretto in Godot, nessuna conversione FBX.
- **Materiali flat senza texture**: 9 materiali, nessuna immagine; il costo di memoria è basso e lo stile è coerente con edifici a colori piatti.
- **Scala corretta**: 1,858 m, origine ai piedi; con 1 unità = 1 m non serve scaling.
- **Licenza CC0** nel file `License.txt` del pack, non solo nella pagina.

**Limiti**

- 5.776 triangoli e 10 primitive: per un solo avatar va bene; se in futuro ci saranno molti NPC, i draw call vanno ottimizzati (merge materiali, LOD, impostor).
- Proporzioni umane normali: a distanze molto grandi (oltre ~30 m) la silhouette è meno leggibile di un chibi. La slice assume una camera a 15–25 m; in caso contrario, valutare un upscale contenuto (1,05–1,10) o un modello più stilizzato.
- La palette è piuttosto spenta (grigio/blu, jeans scuri, scarpe rosse): su edifici grigi può perdersi. Un override del materiale della maglietta con un colore saturo, o una rim light, migliora la leggibilità senza cambiare asset.

### 3.2 KayKit Adventurers — il fallback “premium”

KayKit è un riferimento per qualità e supporto Godot:

- **5 personaggi** nel tier free, **12 MB**, **glTF + FBX**, modelli ottimizzati per mobile, texture atlas 1024×1024 riducibile a 128×128 [S8][S9].
- **Animazioni basiche incluse**; il pack separato **Character Animations** è CC0, con **133 animazioni** sul sito ufficiale e **161** sulla pagina itch aggiornata [S10][S11].
- C’è un **tutorial Godot** ufficiale e una community ampia [S10].

Perché non è la scelta della slice:

- Il tema è **fantasy/chibi**: knight, mage, ranger, barbarian, rogue. In una città moderna stona; i modelli sono molto “testa grande”, quindi leggibili ma cartoon.
- L’animazione richiede più lavoro: il pack base ha solo le animazioni basiche; per avere un set completo bisogna scaricare il pack animazioni e gestire clip separate/retargeting.
- Il flusso è più articolato di un singolo GLB con 24 clip già dentro.

KayKit resta il **fallback** se la direzione artistica vira su un mondo fantasy o se serve un avatar più espressivo e “leggibile” a distanza.

### 3.3 Mixamo — scartato

Mixamo è gratuito con Adobe ID e consente uso commerciale royalty-free, ma:

- **Non è CC0**: Adobe mantiene i diritti sui personaggi e sulle animazioni; il FAQ/community vieta la redistribuzione dei file grezzi come asset [S12][S13].
- Richiede **account Adobe** e un flusso web; i download sono **FBX/OBJ**, non glTF, quindi serve una conversione in Blender [S14][S15].
- I personaggi sono **realistici**, non low-poly: il contrasto con edifici estrusi a colori piatti sarebbe evidente.

Per una slice CC0, offline e low-poly, Mixamo aggiunge vincoli e passaggi senza vantaggi.

### 3.4 Quaternius Universal Base Characters + Universal Animation Library — upgrade futuro

Questa è la coppia più moderna e di qualità:

- **6 modelli base** (Superhero, Regular, Teen; maschile e femminile), **20 acconciature**, **13k tris medi**, rig humanoid retargettabile, compatibile con UAL [S21].
- Standard free: **2 modelli + 5 capelli**, ZIP da **122 MB**; Source: tutti e 6 i modelli + 20 capelli, 600 MB [S21].
- **UAL**: 120+ animazioni totali, **45 gratuite** nello standard (15 MB), root motion on/off, testata in Godot/Unity/Unreal, compatibile con rig comuni [S22].

Perché non per la slice:

- 13k tris medi sono oltre il doppio del modello scelto; per un avatar va anche bene, ma il target è “low-poly mobile”.
- Il free tier è da 122 MB per 2 modelli: troppo per un prototipo.
- Richiede retargeting e due pack separati; la slice ha bisogno di idle/walk subito.

È l’**upgrade path** se l’avatar diventa un elemento centrale (character creator, più varianti, animazioni parkour/combat).

### 3.5 Kenney Mini Characters e Ultimate Animated Character Pack 2019

- **Kenney Mini Characters**: CC0, 25 file, animazioni incluse, ma stile mini/chibi; adatto a un gioco toy, non a un avatar urbano [S23].
- **Quaternius Ultimate Animated Character Pack (2019)**: 52 personaggi, glTF, CC0, “many animations”; include anche outfit moderni (Casual, Suit, Worker). È un’alternativa valida se servono molti NPC, ma è più vecchio e grande del pack 2022, e non dichiara il numero esatto di clip [S24].

## 4. Verifica della licenza alla fonte

### 4.1 Il pack scelto è CC0

Il file `License.txt` dentro la cartella ufficiale del pack contiene:

> `Ultimate Modular Males by @Quaternius`
>
> `License: CC0 1.0 Universal (CC0 1.0) Public Domain Dedication`
>
> `https://creativecommons.org/publicdomain/zero/1.0/`

Fonte: <https://drive.google.com/file/d/1TTvylHa1CsiJuHFWWiv6PFGhLM-aAH5z/view> [S3]. Il testo è stato letto dal preview del file Drive; il download diretto era temporaneamente limitato dalla quota di Google Drive.

La pagina del pack mostra il badge **CC0** con link alla deed [S1], e il FAQ ufficiale di Quaternius conferma che gli asset possono essere usati in progetti commerciali, educativi e personali, senza attribuzione, sotto **CC0** [S4].

### 4.2 Attenzione: Quaternius ha introdotto una licenza propria (QAL) ad agosto 2026

La pagina <https://quaternius.com/license.html> riporta la **Quaternius Asset License (QAL) v1.0**, aggiornata il **28 agosto 2026** [S5]. La QAL consente uso personale, educativo e commerciale, modifica e ridistribuzione **solo come parte di un prodotto**, ma vieta di rivendere/ridistribuire gli asset come asset standalone. La QAL specifica anche che le modifiche **non sono retroattive**: “Changes will not apply retroactively to Assets you've already obtained under an earlier version; the version in effect at the time you obtained the Assets governs your use of them” [S5].

Conseguenza pratica:

- Il pack **Ultimate Modular Men (feb 2022)** include un `License.txt` che dice **CC0**: per quel pack vale il CC0 [S3].
- La QAL riguarda i rilasci nuovi; non cambia la licenza del pack 2022.
- Per evitare ambiguità, conservare nel repo il `License.txt` del pack insieme al modello e alla pagina di provenienza.

### 4.3 Confronto con Mixamo

Adobe dichiara l’uso **royalty-free** per progetti personali, commerciali e non-profit, inclusi i videogiochi [S12]. Tuttavia:

- non è una licenza CC0: Adobe conserva i diritti;
- il FAQ/community vieta di distribuire i file grezzi di personaggi e animazioni a non-membri del team [S13];
- non c'è export glTF nativo: serve FBX/OBJ + Blender [S14][S15].

Per un progetto che vuole una licenza semplice e verificabile, il pack CC0 di Quaternius è più adatto.

## 5. Scheda tecnica del modello scelto

Misure fatte sul GLB del personaggio `Casual` distribuito da Poly Pizza, che corrisponde allo stesso asset Quaternius (stesse 24 clip, stesso rig) [S6][S7]. Il file ufficiale è `Casual_Male.gltf` nel pack [S2].

| Proprietà | Valore | Note |
|---|---|---|
| Altezza | **1,858 m** | AABB del mesh in posa T; origine ai piedi |
| Larghezza in T-pose | 1,675 m | Braccia aperte; larghezza reale in idle molto minore |
| Profondità | 0,455 m | — |
| Triangoli | **5.776** | Conteggio indici/3 |
| Vertici | 11.660 | — |
| Ossa | **62** | Skin con 62 joint |
| Mesh/skin | 4 mesh, 4 skin | Godot importerà 4 `MeshInstance3D` |
| Materiali | **9 flat**, nessuna texture | `StandardMaterial3D` con albedo |
| Primitive | 10 | Fino a 10 draw call per l’avatar |
| File GLB | **1,43 MB** | 1.430.660 byte |
| Animazioni | **24** | Elenco in Appendice A |
| FPS animazioni | **24** | Idle: 41 key / 1,667 s; Walk: 33 key / 1,333 s; Run: 20 key / 0,792 s |
| Idle | 1,667 s | `Idle`, `Idle_Neutral`; loop |
| Walk | 1,333 s | In-place; `Body` translation costante |
| Run | 0,792 s | Opzionale |
| Root motion | **No** | `Walk` non sposta il `Body`; adatto a movimento GPS |
| Fronte | **+Z** | Convenzione glTF/Godot per gli asset [S19][S25] |
| Origine | Ai piedi (y ≈ 0) | Capsule centrata a y = 0,93 m |

**Passo e foot sliding.** Nel clip `Walk`, il piede si sposta di circa **0,88 m** in avanti/indietro; il ciclo dura **1,333 s** e contiene due passi. Velocità nominale ≈ `2 × 0,88 / 1,333` = **1,32 m/s**. È il valore da usare come riferimento per `speed_scale` (sotto).

## 6. Piano di import in Godot 4.7

### 6.1 File da mettere nel repo

Non scaricare l’intero pack nel repo. Creare:

```
res://assets/avatar/
├── casual_male.glb          # oppure casual_male.gltf + casual_male.bin
└── LICENSE-quaternius.txt   # copia del License.txt CC0 del pack
```

- Preferire **`.glb`** se si usa il mirror Poly Pizza (file unico da 1,43 MB) o se si converte il `.gltf` in Blender.
- Se si usa il file ufficiale `.gltf`, tenere il `.bin` nello stesso folder; Godot importa entrambi.
- Non committare l’intero pack (11 personaggi, accessori, formati multipli): serve solo il personaggio scelto.
- Aggiungere un `NOTICE`/`README` con link alla pagina ufficiale e al `License.txt`.

### 6.2 Impostazioni di import

1. Selezionare il file in **FileSystem** e aprire l’**Import** dock.
2. **Root Type**: `Node3D`; **Root Name**: `CasualMale`.
3. **Animation > Import**: attivo.
4. **Animation > FPS**: **24** (il clip è a 24 fps; il default 30 risamplerebbe e cambierebbe leggermente i tempi) [S17].
5. **Animation > Trimming**: **disattivo** per conservare la durata esatta del loop; se si vuole ridurre il file, attivarlo solo dopo aver verificato le durate.
6. **Meshes > Ensure Tangents**: **disattivo** (nessuna normal map/texture).
7. **Meshes > Generate LODs**: **disattivo** per un singolo avatar; rivalutare con molti NPC.
8. **Meshes > Create Shadow Meshes**: attivo (costo basso, 5,8k tris).
9. **glTF > Embedded Texture Handling**: irrilevante (nessuna texture).
10. **Advanced Import Settings** (doppio click sul file):
    - verificare che ci siano **24 animazioni**;
    - impostare **Loop Mode = Linear** su `Idle`, `Idle_Neutral`, `Walk`, `Run`;
    - rinominare le clip in `Idle`, `Walk`, `Run` (o usare i nomi originali `CharacterArmature|Idle`, ecc.);
    - controllare l’anteprima 3D: il personaggio deve essere diritto e alto ~1,86 m.

Riferimenti Godot: formati e glTF raccomandato [S16], opzioni di import e FPS [S17], Advanced Import Settings e loop [S18].

### 6.3 Struttura della scena

```
Avatar (CharacterBody3D)
├── CollisionShape3D (CapsuleShape3D: height 1.8, radius 0.3, position y = 0.9)
├── Visual (Node3D)
│   └── CasualMale (istanza del GLB importato)
│       └── ... AnimationPlayer (creato dall'import)
└── AnimationTree (opzionale, per Run/altre clip)
```

- L’origine del modello è ai piedi: `Visual.position = Vector3.ZERO`; la capsule va centrata a `y = 0.9`.
- Il modello è già alto 1,858 m: **non applicare scale manuali**.
- Se il personaggio appare ruotato, ricordare che il nodo `CharacterArmature` ha una rotazione di -90° X per la conversione Z-up → Y-up; è normale, non aggiungere un’altra rotazione al root.

### 6.4 Movimento e orientamento

- La posizione dell’avatar è guidata dal GPS (ticket 04/07), non dall’animazione: **non abilitare root motion**.
- Il modello guarda **+Z** (i piedi si estendono verso +Z), che è la convenzione Godot per gli asset orientati [S19][S25]. Per ruotarlo verso la direzione di movimento:

```gdscript
var dir := Vector3(velocity.x, 0.0, velocity.z)
if dir.length_squared() > 0.001:
    var target_yaw := atan2(dir.x, dir.z)  # fronte +Z
    visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 12.0 * delta)
```

In alternativa, `look_at(global_position + dir, Vector3.UP, true)` con `use_model_front = true` [S26].

- Se il movimento GPS è rumoroso, applicare un deadzone di ~0,1 m/s e uno smoothing alla velocità prima di scegliere idle/walk, per evitare flicker.

## 7. Piano di animazione

### 7.1 Clip da usare nella slice

| Stato | Clip | Durata | Loop | Note |
|---|---|---|---|---|
| Idle | `Idle_Neutral` (o `Idle`) | 1,667 s | Sì | Posa neutra, adatta alla città |
| Walk | `Walk` | 1,333 s | Sì | In-place; passo ~0,88 m |
| Run (opzionale) | `Run` | 0,792 s | Sì | Solo se la slice prevede corsa |

Le altre 21 clip (combat, gun, wave, interact, death) non servono alla slice; lasciarle importate non ha costo a runtime se non vengono riprodotte. `Wave`/`Interact` potranno servire per POI futuri, fuori scope.

### 7.2 Implementazione minimale (consigliata per la slice)

Usare l’`AnimationPlayer` creato dall’import con crossfade e speed scaling:

```gdscript
extends CharacterBody3D

@export var walk_speed := 1.32  # m/s, dedotto dal clip
@onready var visual: Node3D = $Visual
@onready var anim: AnimationPlayer = $Visual/CasualMale/AnimationPlayer

func _physics_process(delta: float) -> void:
    var speed := Vector2(velocity.x, velocity.z).length()
    if speed > 0.1:
        if anim.current_animation != "Walk":
            anim.play("Walk", 0.15)
        # Evita foot sliding: 1.32 m/s è la velocità nominale del clip
        anim.speed_scale = clampf(speed / walk_speed, 0.7, 1.5)
    else:
        if anim.current_animation != "Idle_Neutral":
            anim.play("Idle_Neutral", 0.15)
        anim.speed_scale = 1.0
```

- `play(name, 0.15)` fa crossfade in 0,15 s; è sufficiente per idle↔walk.
- `speed_scale` compensa la velocità GPS reale: a 1,32 m/s il clip gira a 1,0×; a 1,6 m/s a ~1,21×; a 0,9 m/s a ~0,68× (clampato a 0,7).
- Se il GPS va più piano di 0,9 m/s, meglio accettare un leggero foot sliding che un’animazione da zombie.
- `AnimationPlayer` è dentro l’istanza importata; il path dipende dal nome del nodo root scelto in import. Verificare in editor o usare `find_child("AnimationPlayer")`.

### 7.3 Evoluzione: AnimationTree

Se in seguito si aggiungono `Run`, `Wave`, `Interact` o blend continuo idle/walk/run, passare a `AnimationTree`:

- root `AnimationNodeStateMachine` con stati `Idle`, `Walk`, `Run`;
- transizioni `Idle → Walk` e `Walk → Idle` con `Xfade Time = 0.15`;
- `Walk → Run` a ~2,2 m/s, `Run → Walk` a ~2,0 m/s;
- `AnimationTree.anim_player` punta all’`AnimationPlayer` importato; `active = true`;
- `playback.travel("Walk")` dalle transizioni o dal codice.

Riferimento: `AnimationTree`, StateMachine, BlendSpace e root motion [S20]. Non usare root motion per la posizione: la posizione resta GPS-driven.

### 7.4 Leggibilità a scala urbana

Con 1 unità = 1 m, l’avatar è alto 1,858 m. Con una camera obliqua a 15–20 m e FOV verticale ~50°, occupa circa il **10–13%** dell’altezza dello schermo; a 25 m circa l’8%; a 30 m circa il 6,6%. A 15–25 m le proporzioni umane sono leggibili, soprattutto con un colore ad alto contrasto.

Misure di supporto, in ordine di costo:

1. **Colore**: sovrascrivere il materiale della maglietta con un colore saturo (arancio/rosso/ciano) tramite `surface_override_material`; non modificare il GLB.
2. **Rim light / outline**: un `ShaderMaterial` con Fresnel o un secondo pass di outline; opzionale, da valutare su mobile.
3. **Camera**: tenere l’avatar a 15–25 m (ticket 08); non risolvere la leggibilità con un upscale globale.
4. **Upscale controllato**: solo se la camera resta oltre 30 m, valutare 1,05–1,10×; rompe leggermente la scala 1:1, quindi è l’ultima opzione.

## 8. Rischi e mitigazioni

| Rischio | Impatto | Mitigazione |
|---|---|---|
| Google Drive rate-limited | Non si scarica il pack ufficiale | Usare il GLB Poly Pizza (stesso modello, CC0) per la slice; tenere il link ufficiale e il `License.txt` per provenienza |
| Licenza QAL vs CC0 | Ambiguità sul pack 2022 | Il `License.txt` del pack dice CC0; conservarlo nel repo. La QAL non è retroattiva [S3][S5] |
| 10 draw call / 9 materiali | Costo su mobile con molti NPC | Per un avatar è accettabile; con NPC, unire materiali o usare LOD/impostor |
| Proporzioni normali a camera lontana | Avatar poco leggibile | Camera 15–25 m, colore saturo, rim light; upscale 1,05–1,10 solo se necessario |
| Animazioni a 24 fps importate a 30 | Timing alterato, foot sliding | Impostare `Animation > FPS = 24` [S17] |
| Fronte +Z | Rotazione sbagliata di 180° | Usare `atan2(dir.x, dir.z)` o `look_at(..., use_model_front = true)` [S19][S26] |
| Origine ai piedi | Capsule disallineata | Capsule `height 1.8`, `radius 0.3`, centro `y = 0.9`; visual a `y = 0` |
| Palette spenta | Avatar si perde sullo sfondo | Override materiale maglietta con colore saturo |
| Camera ticket 08 non ancora chiusa | La scelta assume 15–25 m | Se la camera è molto più lontana, rivalutare KayKit (chibi) o upscale |

## 9. Fonti

Tutte le fonti sono state consultate il **31 ottobre 2026**. Le fonti primarie sono le pagine ufficiali degli autori, i file di licenza dentro i pack e la documentazione Godot 4.7.

- **[S1]** Quaternius, *Ultimate Modular Men Pack* — 11 personaggi, 24 animazioni, formati, badge CC0. <https://quaternius.com/packs/ultimatemodularcharacters.html>
- **[S2]** Quaternius, cartella ufficiale Google Drive *Ultimate Modular Men - Feb 2022* (sottocartelle `Individual Characters/glTF`, `License.txt`). <https://drive.google.com/drive/folders/1USAAquX2JJWuA2m6zol0KUkFe3UkZ8zX> — file `Casual_Male.gltf`: <https://drive.google.com/file/d/1rrj82IYNaSWj5ySxR6fW9oojyHFiW7_r/view>
- **[S3]** Quaternius, `License.txt` del pack *Ultimate Modular Men*: “License: CC0 1.0 Universal (CC0 1.0) Public Domain Dedication”. <https://drive.google.com/file/d/1TTvylHa1CsiJuHFWWiv6PFGhLM-aAH5z/view>
- **[S4]** Quaternius, *F.A.Q.* — uso commerciale, senza attribuzione, CC0. <https://quaternius.com/faq.html>
- **[S5]** Quaternius, *Quaternius Asset License (QAL) v1.0*, aggiornata 28 agosto 2026; nota di non retroattività. <https://quaternius.com/license.html>
- **[S6]** Poly Pizza, *Ultimate Modular Men Pack* (Quaternius), licenza “Public Domain (CC0)”, 11 modelli. <https://poly.pizza/bundle/Ultimate-Modular-Men-Pack-ZiH8muWqwQ>
- **[S7]** Poly Pizza, *Casual Character* (Quaternius), 24 animazioni, GLB 1,43 MB; misure tecniche fatte sul file. <https://poly.pizza/m/kZ3DmIoGip> — GLB: <https://static.poly.pizza/90a9e2d4-053f-42f1-99a2-8f5e1180ea7f.glb>
- **[S8]** Kay Lousberg, *Characters: Adventurers* — 5 personaggi, animazioni basiche, atlas 1024, CC0, glTF/FBX. <https://kaylousberg.com/game-assets/characters-adventurers>
- **[S9]** KayKit, *Character Pack: Adventurers* su itch.io — free 12 MB, CC0. <https://kaylousberg.itch.io/kaykit-adventurers>
- **[S10]** Kay Lousberg, *Character Animations* — 133 animazioni, CC0, Godot. <https://kaylousberg.com/game-assets/character-animations>
- **[S11]** KayKit, *Character Animations* su itch.io — free 14 MB, 161 animazioni nella versione corrente. <https://kaylousberg.itch.io/kaykit-character-animations>
- **[S12]** Adobe, *Mixamo — Common questions* (FAQ ufficiale): uso royalty-free per progetti personali, commerciali e non-profit. <https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html> — copia archiviata: <https://web.archive.org/web/20251223230409/https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html>
- **[S13]** Adobe Community, *Mixamo FAQ — Licensing, Royalties, Ownership, EULA and TOS*: divieto di distribuire i file grezzi a non-membri del team. <https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400>
- **[S14]** Meta, *Loading custom 3D models with glTF*: Mixamo non supporta l’export glTF; serve FBX + Blender. <https://developers.meta.com/vr/documentation/spatial-sdk/spatial-sdk-gltfs>
- **[S15]** Adobe Community, *glTF/GLB support* (thread su Mixamo): formati supportati e richiesta glTF. <https://community.adobe.com/questions-696/gltf-glb-support-590054>
- **[S16]** Godot 4.7, *Available 3D formats* — glTF 2.0 raccomandato, `.glb` più compatto. <https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html>
- **[S17]** Godot 4.7, *Import configuration* — Animation FPS, trimming, root type, import script. <https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html>
- **[S18]** Godot 4.7, *Advanced Import Settings* — loop per animazione, anteprima, materiali. <https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/advanced_import_settings.html>
- **[S19]** Godot 4.7, *Model export considerations* — sistema Y-up, +Z fronte per gli asset, convenzione glTF. <https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html>
- **[S20]** Godot 4.7, *Using AnimationTree* — StateMachine, BlendSpace1D/2D, root motion, `travel()`. <https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html>
- **[S21]** Quaternius, *Universal Base Characters* su itch.io — 6 modelli, 13k tris, 122 MB standard, CC0. <https://quaternius.itch.io/universal-base-characters>
- **[S22]** Quaternius, *Universal Animation Library* su itch.io — 120+ animazioni, 45 free standard (15 MB), root motion, CC0. <https://quaternius.itch.io/universal-animation-library>
- **[S23]** Kenney, *Mini Characters* — 25 file, animazioni, CC0. <https://kenney.nl/assets/mini-characters>
- **[S24]** Quaternius, *Ultimate Animated Character Pack* (2019) — 52 modelli, glTF, CC0. <https://quaternius.com/packs/ultimatedanimatedcharacter.html>
- **[S25]** Khronos, *glTF 2.0 Specification — Coordinate System and Units* (metri, Y-up, +Z front). <https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#coordinate-system-and-units>
- **[S26]** Godot 4.7, `Node3D.look_at()` — parametro `use_model_front`. <https://docs.godotengine.org/en/stable/classes/class_node3d.html#class-node3d-method-look-at>

## Appendice A — Le 24 animazioni del GLB verificato

Nomi originali con prefisso `CharacterArmature|`:

```
Death
Gun_Shoot
HitRecieve
HitRecieve_2
Idle
Idle_Gun
Idle_Gun_Pointing
Idle_Gun_Shoot
Idle_Neutral
Idle_Sword
Interact
Kick_Left
Kick_Right
Punch_Left
Punch_Right
Roll
Run
Run_Back
Run_Left
Run_Right
Run_Shoot
Sword_Slash
Walk
Wave
```

Per la slice: `Idle_Neutral`, `Walk`, `Run` (opzionale). Le altre sono utili per NPC o interazioni future, ma fuori scope.

## Appendice B — Metodo di verifica tecnica

Le misure della scheda tecnica sono state ottenute parsando il GLB con uno script Python che legge l’header glTF, il chunk JSON e il buffer binario:

- conteggio animazioni: `len(gltf["animations"])` → 24;
- triangoli: somma di `indices.count / 3` su tutte le primitive → 5.776;
- vertici: somma di `POSITION.count` → 11.660;
- altezza: AABB mondiale dei mesh, componendo le trasformazioni dei nodi → 1,858 m;
- fps: intervalli tra i keyframe (Idle 40 intervalli / 1,667 s; Walk 32 / 1,333 s; Run 19 / 0,792 s) → 24 fps;
- root motion: canale di traslazione del nodo `Body` costante nel clip `Walk` → nessun movimento in avanti;
- passo: range Z dei canali di traslazione di `Foot.L`/`Foot.R` nel clip `Walk` → ~0,88 m per passo.

Il GLB usato per la verifica è il mirror Poly Pizza del modello Quaternius `Casual`; il pack ufficiale contiene lo stesso personaggio come `Casual_Male.gltf` [S2][S7].
