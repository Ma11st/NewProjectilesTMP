# Build & Test — JoJo Stands (beta)

Goal of this doc: get you from "source files" to "punching in-game" with the least
possible Creation Kit work. There are two paths:

- **[A) Fast test path](#a-fast-test-path)** — the ~8 forms needed to see Star Platinum
  barrage/reach/reflex working. Do this first.
- **[B) Full build](#b-full-build)** — everything (acquisition quest, Arrow, MCM, more Stands).

Everything that *can* live in code already does. What remains is genuinely CK/asset work
(records, the ghost mesh, animations, dialogue), because those are binary/GUI artifacts.

---

## 0. Prerequisites

| Requirement | Why |
|-------------|-----|
| **SKSE64** | key input, timers |
| **NewProjectiles** (this repo's mod) | the barrage/reach/ranged volleys |
| **Address Library for SKSE** | NewProjectiles dependency |
| SkyUI | only for the MCM (`JJB_MCM`) — optional |
| CinematicCamera (your upload) | only for time-stop camera (`JJB_TimeStopCamera`) — optional |
| powerofthree's Papyrus Extender | only for a *harder* time-stop AI freeze — optional |

Put the scripts here:
```
Data/Scripts/Source/   <- the .psc files (compile from here)
Data/Scripts/          <- the compiled .pex land here
Data/SKSE/Plugins/NewProjectiles/   <- the newprojectiles/*.json (after editing FormIDs)
```

---

## 1. Compiling the scripts

Compile order doesn't matter (the CK compiler resolves dependencies), but note:

- **Always compile:** `JJB_StandDef`, `JJB_StandManager`, `JJB_StandBondEffect`,
  `JJB_PlayerHitSensor`, `JJB_SoulProfile`, `JJB_Trials`, `JJB_Awakening`,
  `JJB_ArrowEffect`, `JJB_FrozenEffect`, `JJB_DebugAlias`.
- **Optional (skip if you lack the dep):**
  - `JJB_MCM` — needs SkyUI's `SKI_ConfigBase`.
  - `JJB_TimeStopCamera` — needs `CinematicCamera.psc` on the import path (it's the *only*
    script that references CinematicCamera, so skipping it keeps everything else buildable).

CK: *Gameplay → Papyrus Script Manager → right-click → Compile*, or use Caprica/pyro.
NewProjectiles itself must be installed; these scripts don't depend on its source.

---

## A) Fast test path

Minimum forms to see Star Platinum work. ~10 minutes in the CK.

### A.1 Make the records
1. **GlobalVariable** `JJB_Resolve` (Float, value 100) and `JJB_Conviction` (Float, 0).
2. **Keyword** `JJB_StandSightKwd`.
3. **ActorBase** `JJB_StarPlatinumBase` — for a first test, **duplicate a Dremora/ghost
   NPC**. Add `JJB_StandSightKwd`. (Looks don't matter yet; you just want a body.)
4. **Projectile** `JJB_PunchProjectile` — duplicate a fast, short-range projectile
   (e.g. a stripped-down `MAGFireboltProjectile`); make it near-invisible.
5. **Spell** `JJB_PunchSpell` — Fire-and-forget, Aimed; one *Concentration*-ish
   damage effect (e.g. 8 pts). Its delivery projectile = `JJB_PunchProjectile`.
6. **Spell** `JJB_BarrageSpell` — Fire-and-forget, Aimed; its projectile =
   `JJB_PunchProjectile` too. This is the "carrier" cast each tick.
7. **MagicEffect** `JJB_StandBondME` — script effect, **Constant Effect / Self**, no
   visuals. Attach script **`JJB_StandBondEffect`**. Then **Spell/Ability**
   `JJB_StandBondAbility` (Ability) carrying it.
8. **Quest** `JJB_StandQuest` (Start Game Enabled, Run Once OFF):
   - Attach **`JJB_StandManager`** *and* **`JJB_StandDef`**? No — keep them separate:
     - This quest holds `JJB_StandManager` (the singleton).
     - Make a **second quest** `JJB_Def_StarPlatinum` holding `JJB_StandDef`.
   - Add a **player ReferenceAlias** (Specific Reference → PlayerRef) with scripts
     **`JJB_PlayerHitSensor`**, **`JJB_Trials`**, **`JJB_SoulProfile`**, **`JJB_DebugAlias`**.

### A.2 Fill properties (only what the test needs)
- `JJB_Def_StarPlatinum (JJB_StandDef)`: `StandId="star_platinum"`, `Archetype=0`,
  `DisplayName="Star Platinum"`, `CanBarrage=true`, `CanGuard=true`, `CanReach=true`,
  `StandActorBase=JJB_StarPlatinumBase`, `BarrageSpell=JJB_BarrageSpell`,
  `GuardCounterSpell=JJB_BarrageSpell` (reuse), `ReflexNegateSpell=None` (ok).
- `JJB_StandManager`: `Resolve=JJB_Resolve`, `Conviction=JJB_Conviction`,
  `StandSightKeyword=JJB_StandSightKwd`, `StandBondAbility=JJB_StandBondAbility`,
  `Defs = [JJB_Def_StarPlatinum]`. Leave tuning at defaults.
- `JJB_StandBondME` effect script: `Manager=JJB_StandManager`, `DefOverride=None`.
- The player-alias scripts: set every `Manager` property to `JJB_StandManager`;
  `JJB_PlayerHitSensor.Trials=` the Trials script; `JJB_DebugAlias.DebugStandId="star_platinum"`.

### A.3 NewProjectiles config
Copy `newprojectiles/JJB_StarPlatinum_Barrage.json` to
`Data/SKSE/Plugins/NewProjectiles/` and replace the three FormIDs with your real
`JJB_BarrageSpell` / `JJB_PunchProjectile` / `JJB_PunchSpell` IDs.

### A.4 Test
1. New game / coc to a test cell with an enemy.
2. Press **F9** (debug: awaken Star Platinum). You should see *"Your Stand awakens"*.
3. Press **X** (stance → *"ready"*).
4. **Hold Q** near the enemy → the ghost flickers in and rains a fist cluster each tick;
   release → it vanishes.
5. Press **F** at a target → a single Star Finger strike.
6. Let the enemy land a heavy hit → a Reflex flicker should fire (if Resolve ≥ 25).
7. **F10** refills Resolve, **F8** +Conviction, **F7** max Mastery (to feel the cadence change).

If the barrage does nothing: the NewProjectiles JSON FormIDs don't match — recheck A.3.

---

## B) Full build

Do everything in **`ck-setup/FORMS.md`** (it lists every form → property), plus:

- **Acquisition quest:** an awakening scene; put **`JJB_Awakening`** on that quest, set its
  `Profile` to the player's `JJB_SoulProfile` alias. Dialogue answers call
  `(GetOwningQuest() as JJB_Awakening).Answer(0..3)`, scene end calls `.Finish()`.
- **The Arrow:** a one-shot lesser power "Use the Arrow" (Self) with a script MagicEffect
  carrying **`JJB_ArrowEffect`** (`Manager`, `Profile` set). Gate access however you like.
- **Reach (Star Finger):** add `JJB_FingerProjectile`, `JJB_FingerSpell`, `JJB_ReachSpell`
  (carrier), set `ReachSpell` on the def, and install `JJB_StarPlatinum_StarFinger.json`.
- **Time-stop (optional):** `JJB_TimeStopCloak` = a **Fire-and-forget, Self, large Area**
  spell whose effect uses **`JJB_FrozenEffect`** (set the effect Duration = stop length);
  set `TimeStopCloak` on the def + `CanTimeStopBrief=true`. Optionally attach
  `JJB_TimeStopCamera` and point `JJB_StandManager.Camera` at it.
- **MCM (optional):** quest (Start Game Enabled) with **`JJB_MCM`**, `Manager` set. SkyUI
  auto-registers it; rebinds call `RebindKeys()` for you.
- **More Stands:** one `JJB_StandDef` quest per entry in `data/StandDefs.json`; add each to
  `Manager.Defs[]`. For an **enemy** user, duplicate the bond ability, set its effect's
  `DefOverride` to that Stand's def, and add it to the NPC.

---

## C) Property-values appendix (recommended)

`JJB_StandManager` (defaults are sane; tune in the MCM):
| Property | Default | Property | Default |
|----------|---------|----------|---------|
| ResolveMax | 100 | BarrageTickInterval | 0.12 |
| ResolveRegenPerSec | 12 | BarrageMaxDuration | 3.0 |
| ResolveRegenDelay | 1.5 | BarrageRecovery | 0.6 |
| CostBarragePerSec | 22 | GuardWindowSeconds | 0.30 |
| CostGuard | 15 | ReflexWindowSeconds | 0.30 |
| CostReflex | 25 | ReachRange | 512 |
| CostReach | 10 | ReflexHealthFrac | 0.20 |
| BarrageKey | 16 (Q) | StanceKey | 45 (X) |
| ReachKey | 33 (F) | TimeStopKey | 19 (R) |
| ArrowBaseSurvival | 0.10 | ArrowConvictionScale | 0.009 |
| TimeStopDuration | 5.0 | OffsetForward/Right/Up | 70 / 35 / 0 |

`JJB_StandDef` per-Stand values: copy straight from the matching `data/StandDefs.json`
entry (capabilities, archetype, the `*Max*` mastery deltas, sub-ability thresholds,
`NpcPrecision/NpcFerocity`, evolution links).

Debug hotkeys (`JJB_DebugAlias`): F9 awaken / F10 resolve / F8 conviction / F7 mastery.

---

## D) What I could NOT generate here (true CK/asset work)

- The binary `JoJoStands.esp` (records are made in the CK GUI).
- The ghost mesh/skeleton + the attack/idle animations the anim-event strings drive
  (`JJB_BarrageStart/Stop`, `JJB_GuardCatch`, `JJB_ReflexBlock`, `JJB_Reach`, `JJB_TimeStop`).
  For the fast test, a vanilla NPC body + default idles is enough to see it work.
- Voiced lines (the awakening dialogue can ship silent/subtitled).

Everything else — logic, configs, tuning, the test harness, this guide — is done.
