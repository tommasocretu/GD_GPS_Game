# Importare l'avatar Quaternius

Type: task
Status: resolved
Blocked by: —

## Question

Scaricare il pack Quaternius *Ultimate Modular Men* (feb 2022), verificare la licenza CC0 nel file `License.txt`, importare `casual_male.glb` in `res://assets/avatar/` con le impostazioni del report 06 (FPS 24, loop Idle/Walk/Run, fronte +Z, capsule 1,8 m) e collegare un'animazione di prova.

Fatto quando: l'avatar si vede in una scena di test con idle/walk. L'answer registra versione del pack, licenza e path.

## Answer

**Fatto.** Asset importato da Poly Pizza (mirror ufficiale dello stesso GLB Quaternius, 1.430.660 byte):

- Path: `res://assets/avatar/casual_male.glb`;
- Provenienza e licenza: `res://assets/avatar/LICENSE-quaternius.txt` (CC0 1.0, pack febbraio 2022; la QAL di agosto 2026 non è retroattiva);
- Import: `animation/fps=24`, trimming off, 24 clip; i loop `Idle`/`Walk`/`Run` vengono impostati a runtime in `AvatarController` (`Animation.LOOP_LINEAR`), perché le impostazioni per-clip non sono affidabili nel file `.import`;
- Fronte `+Z` confermato; altezza 1,858 m, scala 1.0;
- Animazioni collegate in `scripts/avatar/avatar_controller.gd`: Idle/Walk/Run con crossfade 0.2 s; il modello è visibile nella scena `Main.tscn`.

Verifica: screenshot desktop con avatar in idle e in camminata (fake GPS) e test headless del modello di movimento.
