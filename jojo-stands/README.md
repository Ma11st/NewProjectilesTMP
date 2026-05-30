# JoJo Stands (beta) — OVA-faithful Stand framework

A Skyrim Stand framework where Stands behave like the **OVA**: bound spirits that
**flicker into existence only to perform a single action** — a rush, a parry, a
reflexive save, a reach — and then vanish. There is **no persistent "summon"** that
parks a Stand on the field.

This folder is the **code + config + design** half of the mod. The Creation Kit
half (the `JoJoStands.esp`: actors, spells, art, quest) is built on your machine
following [`ck-setup/FORMS.md`](ck-setup/FORMS.md). Nothing here hard-codes a
FormID — every game form is a script property you fill in the CK.

## What's in here

| Path | What it is |
|------|------------|
| [`DESIGN.md`](DESIGN.md) | The design bible: the "Flicker" state machine, the four action windows, the Resolve economy, the roster. **Read this first.** |
| [`PROGRESSION.md`](PROGRESSION.md) | The RPG layer (design): acquisition (milestone + Arrow), the three growth layers (Resolve/Mastery/Conviction), the four evolution modes (Mastery/ACT/Requiem/sub-abilities), Stand assignment, enemy users, visibility, OVA guardrails. |
| `scripts/source/*.psc` | Papyrus that implements the system. |
| `newprojectiles/*.json` | Barrage / ranged volleys for the [NewProjectiles](../README.md) engine. Validated against the repo `schema.json`. |
| `data/StandDefs.json` | Data-driven Stand registry (extension point). |
| `ck-setup/FORMS.md` | The Creation Kit build checklist, every form → script property. |

## How a "punch storm" works with one button

One barrage keypress does **not** script dozens of punches. Instead:

```
hold Q ──► JJB_StandController.BarrageStart()
              │  manifest the Stand (flicker in)
              │  every 0.12s, while Resolve lasts:
              ▼
        BarrageSpell.Cast(player)
              │
              ▼
   NewProjectiles trigger (JJB_StarPlatinum_Barrage.json)
        event "Cast" + spell == BarrageSpell
              │  ApplyMultiCast key_MC_punch
              ▼
   a tight FillCircle of 5 fast "fist" projectiles, each homing
   onto the nearest hostile  ──►  reads as ORA ORA ORA
release Q ─► BarrageStop() → Stand flickers out → short recovery
```

So the volley shape/spread/tracking lives in JSON (tune without recompiling), and
Papyrus only owns the *when* (the manifestation window + Resolve).

## The scripts

| Script | Role |
|--------|------|
| `JJB_StandController` (Quest) | The brain. Owns the Stand actor, the four action windows, Resolve. The rules live here. |
| `JJB_StandBondEffect` (ActiveMagicEffect) | Input layer on the player: barrage/stance/reach keys + Resolve regen. Requires SKSE. |
| `JJB_PlayerHitSensor` (ReferenceAlias) | Watches incoming hits → asks the controller for a reflexive save. |

## Controls (defaults, rebindable in the CK / a future MCM)

| Key | Action |
|-----|--------|
| `X` | Toggle **Stand-Stance** (intent only — does **not** make the Stand visible) |
| `Q` (hold) | **Barrage** rush while in stance |
| `F` | **Reach / parry** flicker |
| — (automatic) | **Reflex** save when you take a heavy hit and have Resolve |

## Dependencies

- **NewProjectiles** (this repo) — required, drives the volleys.
- **SKSE64** — required (key input / timing).
- **CinematicCamera** (the uploaded DLL) — optional, only for The World's time-stop finisher.
- A power-meter HUD pointed at the `Resolve` global — optional.

## Status (beta)

- ✅ Flicker state machine, Resolve economy, barrage/guard/reflex windows (Papyrus).
- ✅ Star Platinum barrage + Hierophant Green ranged volley (NewProjectiles JSON, schema-valid).
- ✅ Data-driven registry + capability/mastery/evolution schema (`data/StandDefs.json`).
- ✅ RPG layer **designed** (`PROGRESSION.md`): acquisition, growth, evolution, assignment, visibility.
- ⬜ RPG layer **implemented**: per-actor controller refactor, Mastery/Conviction, soul-profile assignment, Arrow/Requiem, visibility keyword.
- ⬜ The World **time-stop** (designed, shipped disabled).
- ⬜ Behavior-graph attack animations for the ghost (you supply / remap anim events).
- ⬜ MCM for live tuning.
- ⬜ Multiple-Stand NPC users (unblocked by the per-actor refactor).

## Building the playable mod

1. Build `JoJoStands.esp` per [`ck-setup/FORMS.md`](ck-setup/FORMS.md).
2. Compile the `.psc` files (CK Papyrus compiler or `caprica`) against SKSE.
3. Drop the `newprojectiles/*.json` into the NewProjectiles config folder and
   swap the placeholder FormIDs for your real ones.
4. Grant the player `JJB_StandBondAbility` and test: toggle stance (`X`), hold `Q`.

See [`DESIGN.md`](DESIGN.md) §6–§7 for adding new Stands and the time-stop plan.
