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
| [`BUILD.md`](BUILD.md) | **Build & test guide.** A fast ~10-min test path to see Star Platinum working, the full build, and a property-values appendix. Start here when you open the CK. |
| `scripts/source/*.psc` | Papyrus that implements the system. |
| `newprojectiles/*.json` | Barrage / ranged volleys for the [NewProjectiles](../README.md) engine. Validated against the repo `schema.json`. |
| `data/StandDefs.json` | Data-driven Stand registry (extension point). |
| `ck-setup/FORMS.md` | The Creation Kit build checklist, every form → script property. |

## How a "punch storm" works with one button

One barrage keypress does **not** script dozens of punches. Instead:

```
hold Q ──► JJB_StandBondEffect.BarrageStart()   (the player's per-actor brain)
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
| `JJB_StandBondEffect` (ActiveMagicEffect) | **The per-actor brain.** Carried on a bond ability, so the player *and* enemy NPCs each get their own Stand, Resolve, and state machine. Owns the four action windows + manifestation + capability gating. Player = key input; NPC = simple combat AI. |
| `JJB_StandDef` (Quest, one per Stand) | Static data for a Stand: capabilities, forms, mastery/evolution. Runtime mirror of a `data/StandDefs.json` entry. |
| `JJB_StandManager` (Quest, singleton) | Global tuning, the def registry, the player's Conviction/Mastery, and awakening. |
| `JJB_PlayerHitSensor` (ReferenceAlias) | Routes heavy incoming hits to the player's bond effect for a Reflex save. |
| `JJB_SoulProfile` (ReferenceAlias) | Playstyle + awakening-dialogue scoring → archetype → which Stand you get. |
| `JJB_Trials` (ReferenceAlias) | Turns bravery moments (clutch survival, outnumbered) into Conviction. |
| `JJB_Awakening` (Quest) | Drives the awakening scene; one-liner hooks for dialogue answers. |
| `JJB_ArrowEffect` (ActiveMagicEffect) | The Stand Arrow: survival check → awaken, or Requiem if already a user. |
| `JJB_FrozenEffect` (ActiveMagicEffect) | Time-stop freeze applied to caught non-users. |
| `JJB_TimeStopCamera` (Quest, optional) | The only script that touches CinematicCamera. |
| `JJB_MCM` (Quest, optional) | SkyUI menu: status, live tuning, key rebinding, debug buttons. |
| `JJB_DebugAlias` (ReferenceAlias) | Test hotkeys (awaken/refill/conviction/mastery). |

> **Per-actor refactor:** the old singleton `JJB_StandController` is gone — its logic now
> lives on `JJB_StandBondEffect` so any actor can be a Stand user. See `PROGRESSION.md` §5.

## Controls (defaults, rebindable in the CK / a future MCM)

| Key | Action |
|-----|--------|
| `X` | Toggle **Stand-Stance** (intent only — does **not** make the Stand visible) |
| `Q` (hold) | **Barrage** rush while in stance |
| `F` | **Reach / Star Finger** — one long strike |
| `R` | **Time-Stop** (only if the Stand can, and you've unlocked it) |
| — (automatic) | **Reflex** save when you take a heavy hit and have Resolve |

Keybinds live on `JJB_StandManager` and are rebindable live in the **MCM** (SkyUI).
Debug/test hotkeys (`JJB_DebugAlias`): **F9** awaken · **F10** refill Resolve · **F8** +Conviction · **F7** max Mastery.

## Dependencies

- **NewProjectiles** (this repo) — required, drives the volleys.
- **SKSE64** — required (key input / timing).
- **SkyUI** — optional, only for the `JJB_MCM` menu.
- **CinematicCamera** (the uploaded DLL) — optional, only for the time-stop camera.
- **powerofthree's Papyrus Extender** — optional, only for a harder time-stop AI freeze.
- A power-meter HUD pointed at the `Resolve` global — optional.

## Status (beta)

- ✅ Flicker state machine, Resolve economy, barrage/guard/reflex windows (Papyrus).
- ✅ Star Platinum barrage + Hierophant Green ranged volley (NewProjectiles JSON, schema-valid).
- ✅ Data-driven registry + capability/mastery/evolution schema (`data/StandDefs.json`).
- ✅ RPG layer **designed** (`PROGRESSION.md`): acquisition, growth, evolution, assignment, visibility.
- ✅ RPG layer **implemented (Papyrus)**: per-actor refactor (enemy users possible), Resolve/Mastery/Conviction, capability gating, soul-profile assignment + awakening, Trials → breakthroughs, Requiem ritual.
- ✅ Reach/Star Finger, **time-stop** (freeze + optional camera), the **Arrow** item, awakening dialogue glue, **NPC reflex**, **MCM** (SkyUI), and a **debug/test harness**.
- ✅ **Test path**: see [`BUILD.md`](BUILD.md) §A — ~10 min of CK to punch in-game.
- ⬜ CK build of `JoJoStands.esp` (records, ghost mesh + animations, dialogue VO) — `ck-setup/FORMS.md` + `BUILD.md`.
- ⬜ ACT form-switching flow (engine-supported via `NextActDef`, unwired for the SC roster).
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
