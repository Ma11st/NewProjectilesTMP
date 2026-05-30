# Creation Kit build checklist — JoJo Stands (beta)

Everything below is created in the Creation Kit and saved into a plugin
(`JoJoStands.esp`). Placeholder FormIDs in the JSON/data files (e.g.
`JoJoStands.esp|0x000D62`) are examples — use whatever the CK assigns and update
the NewProjectiles `FormIDs` blocks + `data/StandDefs.json` to match.

> Every game-specific form is a script **Property you fill in the CK** — no
> hard-coded FormIDs in code.

**Architecture (after the per-actor refactor):**
- **`JJB_StandManager`** — one quest, the singleton. Global tuning + def registry +
  the player's Conviction/Mastery + awakening.
- **`JJB_StandDef`** — one quest *per Stand*. All of that Stand's forms + capabilities
  + mastery/evolution data. (Runtime mirror of an entry in `data/StandDefs.json`.)
- **`JJB_StandBondEffect`** — the per-actor brain, carried on a constant-effect ability.
  Applied to the player at awakening, or to an enemy NPC to make them a Stand user.
- Player aliases: **`JJB_PlayerHitSensor`**, **`JJB_SoulProfile`**, **`JJB_Trials`**.

---

## 1. Globals & keyword
| Form | Fills property (on) | Notes |
|------|----------------------|-------|
| `JJB_Resolve` | `Manager.Resolve` | GlobalVariable, default 100. Point a HUD widget at it. |
| `JJB_Conviction` | `Manager.Conviction` | GlobalVariable, default 0. Soul growth; gates ACT/Requiem. |
| `JJB_StandSightKwd` | `Manager.StandSightKeyword` + ghost ActorBases | Perception gate — only actors with it can target/perceive a manifested Stand (PROGRESSION §6). |

## 2. The bond ability
| Form | Notes |
|------|-------|
| `JJB_StandBondAbility` | Constant-effect ability carrying **`JJB_StandBondEffect`**. Fill the effect's `Manager` property. Leave `DefOverride` **None** on the player ability. → `Manager.StandBondAbility`. Granted automatically by `Manager.AwakenPlayer()`. |
| `JJB_StandBondAbility_<NPCStand>` | (per enemy) a copy whose effect's `DefOverride` = that NPC's `JJB_StandDef`. Add to the NPC to make them a Stand user. |

## 3. Per-Stand: one `JJB_StandDef` quest each
Create `JJB_Def_StarPlatinum`, `JJB_Def_HierophantGreen`, … each with the
**`JJB_StandDef`** script. Fill from the matching `data/StandDefs.json` entry:
- `StandId` (must match the JSON key, e.g. `"star_platinum"`), `Archetype` (0 Power/1 Finesse/2 Control/3 Insight), `DisplayName`, `IsVariant`.
- Capability bools: `CanBarrage` / `CanGuard` / `CanReach` / `CanRanged` / `CanTimeStopBrief`.
- Forms: `StandActorBase`, `BarrageSpell`, `RangedSpell`, `GuardCounterSpell`, `ReflexNegateSpell`, `ManifestShader`, `DismissShader`.
- Mastery/evolution: the `*Max*` deltas, sub-ability thresholds, `NpcPrecision/NpcFerocity`, and `ActsSupported`/`NextActDef`, `RequiemSupported`/`RequiemDef`/`Requiem*Min`.

Then list **every** def quest in `Manager.Defs[]`.

### Forms each def needs
| Form | Type | Goes in def property | Notes |
|------|------|----------------------|-------|
| `JJB_<Stand>Base` | ActorBase | `StandActorBase` | The ghost body. Spawned & puppeted per user. Add `JJB_StandSightKwd`. Give it the anim events `PlayStandAnim` sends (`JJB_BarrageStart/Stop`, `JJB_GuardCatch`, `JJB_ReflexBlock`) or remap those strings. |
| `JJB_<Stand>BarrageSpell` | Spell (hidden) | `BarrageSpell` | Cast each barrage tick; its projectile base = the "fist"/shard proj. NewProjectiles fans it into a cluster. |
| `JJB_<Stand>PunchSpell` | Spell | (NewProjectiles JSON `key_punchSpell`) | Carries the per-hit MagicEffect/damage. |
| `JJB_<Stand>Proj` | Projectile | (NewProjectiles JSON `key_punchProj`/`key_shardProj`) | Short-lived, fast hitbox. |
| `JJB_<Stand>GuardCounter` | Spell | `GuardCounterSpell` | Optional parry riposte. |
| `JJB_<Stand>ReflexNegate` | Spell | `ReflexNegateSpell` | Self-cast on Reflex: heal ≈ `ReflexNegationFrac` of the hit + brief stagger-immunity. |
| `JJB_ManifestShader` / `JJB_DismissShader` | EffectShader | `ManifestShader` / `DismissShader` | Flicker in/out. Optional, shareable across Stands. |

> The ghost is **spawned at runtime** (`PlaceAtMe`) from `StandActorBase`, so you do
> **not** need a pre-placed reference anymore — this is what lets every actor (player
> and NPCs) have their own.

## 4. The Manager quest
Create `JJB_StandManager` (Start Game Enabled) with the **`JJB_StandManager`** script:
- Fill `Resolve`, `Conviction`, `StandSightKeyword`, `StandBondAbility`, and `Defs[]`.
- Tuning properties (`ResolveMax`, costs, intervals, offsets, windows) default sensibly; tune to taste.

## 5. Player aliases (on your main `JJB_StandQuest`, Start Game Enabled)
| Alias script | Properties | Role |
|--------------|-----------|------|
| `JJB_PlayerHitSensor` | `Manager`, `Trials` | Routes heavy incoming hits to the player's bond effect for a Reflex save. |
| `JJB_SoulProfile` | `Manager` | Tallies playstyle + dialogue answers → archetype → which Stand you awaken. |
| `JJB_Trials` | `Manager` | Converts bravery moments (clutch survival, outnumbered) into Conviction. |

All three go on a **player** ReferenceAlias (you can stack scripts on one alias).

## 6. Acquisition wiring
- **Awakening (milestone):** at the right quest stage, run the awakening scene, then call
  `(JJB_SoulProfile alias).RunAwakening()`. It resolves the archetype and calls
  `Manager.AwakenPlayer()`, which sets `PlayerDef` and adds `StandBondAbility`.
- **Awakening dialogue ("personality test"):** each answer's script fragment calls
  `(SoulProfile).AddArchetypePoints(archetype, amount)` before `RunAwakening()`.
- **The Arrow (item):** a MiscObject/quest that, on use, runs a survival check gated by
  `Conviction` (low Conviction → likely death). On success, route to awakening (latent
  user) **or** to `Manager.TryRequiemRitual()` if the user already has a Stand.
- **Story breakthroughs:** call `Manager.GrantBreakthrough("reason", amount)` from any
  dramatic quest stage.

## 7. NewProjectiles configs
Copy `../newprojectiles/*.json` into `Data/SKSE/Plugins/NewProjectiles/` and update their
`FormIDs` to your real values. Already validated against the repo `schema.json`.

## 8. (Optional) CinematicCamera for time-stop
Only for The World's time-stop finisher: `CinematicCamera.LoadAndLaunch("<path>")` then
`CinematicCamera.Stop()`. Disabled in beta.

## 9. Notes / gaps you supply
- **Animations:** the ghost ActorBase needs idles/attacks bound to the anim-event strings
  above (or remap them). Puppeted ghosts don't need combat AI.
- **Offensive playstyle inference** (`JJB_SoulProfile.NoteAttack`) is optional — wire it
  from the player's own swing/cast events if you want richer archetype detection; otherwise
  defense + the dialogue carry it.
- **Outnumbered trial** uses a stubbed headcount; for an exact count, feed `JJB_Trials`
  an alias-collection size or a PO3/PapyrusUtil actor scan.
