# Creation Kit build checklist — JoJo Stands (beta)

Everything below has to be created in the Creation Kit and saved into a plugin
(`JoJoStands.esp`). The placeholder FormIDs in the JSON/data files (e.g.
`JoJoStands.esp|0x000D62`) are just examples — use whatever IDs the CK assigns
and update the JSON `FormIDs` blocks + `data/StandDefs.json` to match.

> The Papyrus scripts are written so that **every game-specific form is a script
> Property you fill in the CK** — no hard-coded FormIDs in code.

## 1. The Stand ghost actor
| Form | Type | Notes |
|------|------|-------|
| `JJB_StarPlatinumBase` | ActorBase (NPC) | The ghost mesh/skeleton. Flagged not-persistent-AI, no combat AI package needed (it's puppeted). Give it the punch attack idles referenced by `PlayStandAnim` (`JJB_BarrageStart/Stop`, `JJB_GuardCatch`, `JJB_ReflexBlock`) or remap those strings to your behavior's events. |
| `JJB_StarPlatinumREF` | placed ObjectReference | Drop one instance in an interior cell, **Initially Disabled** + **Persistent**. → `JJB_StandController.StandActor`. |

## 2. Spells / magic effects
| Form | Fills property | Purpose |
|------|----------------|---------|
| `JJB_BarrageSpell` | `BarrageSpell` | Hidden spell cast each barrage tick. Its projectile's base = `JJB_PunchProjectile`. NewProjectiles fans it into a cluster. |
| `JJB_PunchSpell` | (named in barrage JSON `key_punchSpell`) | The spell each spawned fist carries — put the punch MagicEffect/damage here. |
| `JJB_GuardCounterSpell` | `GuardCounterSpell` | Optional single-bolt parry riposte. Can be left None. |
| `JJB_ReflexNegateSpell` | `ReflexNegateSpell` | Self-cast on Reflex: a quick heal (≈ `reflexNegationFrac` of the hit) + a short stagger-immunity perk/effect. |
| `JJB_StandBondAbility` | (carries `JJB_StandBondEffect`) | Constant-effect ability granted to the player when they get the Stand. |

## 3. Projectiles
| Form | Named in | Notes |
|------|----------|-------|
| `JJB_PunchProjectile` | barrage JSON `key_punchProj` | Short-lived, fast, near-invisible (the "fist" hitbox). Give it a punch impact/art. |
| `JJB_ShardProjectile` | emerald-splash JSON `key_shardProj` | For Hierophant Green. |

## 4. Art / shaders / sound
| Form | Fills property | Notes |
|------|----------------|-------|
| `JJB_ManifestShader` | `ManifestShader` | Flicker-in EffectShader. Optional. |
| `JJB_DismissShader` | `DismissShader` | Flicker-out EffectShader. Optional. |

## 5. Globals
| Form | Fills property | Notes |
|------|----------------|-------|
| `JJB_Resolve` | `Resolve` | GlobalVariable, default 100. Point a HUD widget at it if you want a meter. |

## 6. Quest wiring
Create `JJB_StandQuest` (Start Game Enabled, run-once not required):
- Attach script **`JJB_StandController`** to the quest and fill all its properties above.
- Add a **player ReferenceAlias** with script **`JJB_PlayerHitSensor`**; set its
  `Controller` property to the quest.
- The `JJB_StandBondEffect` ability's effect script also has a `Controller`
  property → point it at the quest.

## 7. Granting the Stand
Hand the player `JJB_StandBondAbility` however the fiction wants — a quest reward,
a "you've been pierced by the Arrow" event, a power, etc. Removing the ability
cleanly tears the bond down (`OnEffectFinish` dismisses any active manifestation).

## 8. NewProjectiles configs
Copy the files in `../newprojectiles/` into
`Data/SKSE/Plugins/NewProjectiles/` (or wherever this build reads its JSONs),
and update their `FormIDs` to the real values from steps 2–3. They're already
validated against the repo's `schema.json`.

## 9. (Optional) CinematicCamera for time-stop
Only needed for The World's time-stop finisher. Calls
`CinematicCamera.LoadAndLaunch("<path>")` then `CinematicCamera.Stop()`.
Disabled in beta.
