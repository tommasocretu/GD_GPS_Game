# Avatar low-poly CC0 con animazioni

Type: research
Status: resolved
Blocked by: —

## Question

Quale asset usare per l'avatar 3D della slice, con animazioni idle/walk e proporzioni leggibili a scala urbana?

Confrontare pack CC0/low-royalty (KayKit, Quaternius, Mixamo e alternative), formato glTF, numero di animazioni, dimensioni, stile coerente con edifici low-poly. Output: scelta, licenza, link, piano di import in Godot e animazione. Findings in `.scratch/gps-game/research/06-avatar.md`.

## Answer

**Scelta:** Quaternius *Ultimate Modular Men* (feb 2022), personaggio `Casual_Male` (alternativa `Casual_Female`): **CC0 1.0** verificata nel `License.txt` del pack, **glTF**, **24 animazioni** incluse (Idle/Idle_Neutral/Walk/Run), **1,858 m**, **5.776 tris**, **1,43 MB** il GLB, materiali flat senza texture.

**Perché:** umano moderno low-poly, coerente con edifici OSM; un solo file con idle/walk già dentro, nessun retargeting. KayKit è CC0 e ottimo ma chibi-fantasy; Mixamo non è CC0 e richiede FBX→glTF; Universal Base + UAL è l'upgrade futuro ma 13k tris/122 MB. Attenzione: Quaternius ha una nuova QAL (ago 2026) non retroattiva; il pack 2022 resta CC0.

**Import Godot 4.7:** copiare solo `casual_male.glb` (+ `LICENSE-quaternius.txt`) in `res://assets/avatar/`; Import dock: Animation ON, **FPS 24**, Trimming OFF; Advanced Import: loop `Linear` su Idle_Neutral/Walk/Run e rinomina a `Idle`/`Walk`/`Run`. `CharacterBody3D` + capsule 1,8 m (centro y=0,9), visual a y=0, fronte **+Z** (`look_at(..., use_model_front=true)`).

**Animazione:** `AnimationPlayer.play("Walk", 0.15)` con crossfade; `speed_scale = clamp(speed / 1.32, 0.7, 1.5)` (passo 0,88 m, ciclo 1,333 s → 1,32 m/s, niente foot sliding); Idle a speed_scale 1. Walk in-place, **niente root motion**. Se si aggiunge Run: AnimationTree StateMachine.

Report completo con fonti, misure e piano dettagliato: [`../research/06-avatar.md`](../research/06-avatar.md).
