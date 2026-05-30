# JoJo's Bizarre Adventure — Stands (OVA-faithful) — Design Bible

> **Beta framework.** Goal: Stands that *feel like spirits/ghosts* — they are bound to
> their user but are **not** persistent summoned pets. They flicker into existence only to
> perform a specific action (a rush, a precise block, a catch, a reach) and then vanish.
> This is modeled after the 1993/2000 **OVA** tone, not the later anime where Stands hover
> beside their user indefinitely.
>
> **The RPG layer** — acquisition, progression, evolution (ACT/Requiem), enemy Stand users,
> and who can see Stands — lives in its companion doc [`PROGRESSION.md`](PROGRESSION.md).
> Roster is **Stardust Crusaders / OVA only** unless expanded deliberately.

---

## 1. Design pillars

1. **No free summon.** There is no "summon Stand" button that parks a Stand next to you.
   The Stand is invisible and absent from the world by default. The *only* way it appears
   is as a side effect of a concrete action you commit to.
2. **Flicker, don't hover.** Every manifestation is a *window* with a start, a purpose, and
   an automatic end. When the purpose is served, the Stand de-manifests. Windows are short
   (0.3s for a reflex block, ~1.5–3s for a barrage).
3. **The user acts; the Stand executes.** You aim, time, and commit. The Stand is the
   delivery mechanism — the ORA-ORA, the parry, the Star Finger reach.
4. **Spiritual cost.** Manifesting spends a regenerating resource ("Resolve"). You cannot
   spam manifestations; over-extending leaves you exposed (the spirit needs to gather).
5. **Data-driven & extensible.** Adding a new Stand = one entry in `data/StandDefs.json` +
   a small set of Creation Kit forms. The barrage volley/spread lives in NewProjectiles JSON.

---

## 2. The manifestation model ("Flicker" state machine)

A bound Stand is always in exactly one state:

```
            ┌──────────────────────────────────────────────────────┐
            │                       DORMANT                         │  (invisible, absent)
            │   - listening for triggers   - regenerating Resolve   │
            └───────┬───────────────┬───────────────┬──────────────┘
                    │ barrage input │ well-timed     │ heavy/lethal
                    │ (hold)        │ block          │ incoming hit
                    ▼               ▼                ▼
              ┌───────────┐   ┌───────────┐    ┌───────────┐
              │  BARRAGE  │   │   GUARD   │    │  REFLEX   │
              │ (rush)    │   │ (parry)   │    │ (auto)    │
              └─────┬─────┘   └─────┬─────┘    └─────┬─────┘
                    │ window end / out of Resolve     │
                    └───────────────┴────────────────-┘
                                    ▼
                               DORMANT  (fade out, disable)
```

There is deliberately **no `MANIFEST_IDLE` state** — you can never simply have the Stand
out. (A `STANCE` intent toggle exists, but it changes *behavior thresholds only*, it does
**not** make the Stand visible. See §5.)

### State transitions

| From    | Trigger                                                | To      | Resolve |
|---------|--------------------------------------------------------|---------|---------|
| Dormant | Hold barrage key (default `Q`) while Stand-stance on    | Barrage | spend   |
| Dormant | Block within the parry window of an incoming attack     | Guard   | spend   |
| Dormant | Take a hit ≥ reflex threshold (and Resolve available)   | Reflex  | spend   |
| Dormant | Reach/precision input on a valid target (catch, pull)   | Guard*  | spend   |
| Barrage | Window timer ends, or Resolve hits 0, or you’re staggered | Dormant | —     |
| Guard   | Parry resolved (deflect + riposte fires)                | Dormant | —       |
| Reflex  | Single block frame resolves (negate + shove)            | Dormant | —       |

\* "Reach" reuses the Guard manifestation shell with a different animation/effect payload.

---

## 3. The four action windows

### 3.1 Barrage ("ORA ORA ORA" / "MUDA MUDA MUDA")
- **Input:** *hold* the barrage key. The Stand flickers in beside/ahead of the user, plays
  the rush animation, and for the duration of the hold (capped by `BarrageMaxDuration` and
  by Resolve) repeatedly fires the barrage volley.
- **Damage delivery:** a hidden "barrage" spell is cast each tick; **NewProjectiles** turns
  that single cast into a tight fan of fast melee-range hits (see
  `newprojectiles/JJB_StarPlatinum_Barrage.json`). This is what makes a single button feel
  like dozens of punches without per-punch scripting.
- **End:** release the key, hit the duration cap, or run out of Resolve → instant fade-out.
- **Vulnerability:** there is a short `BarrageRecovery` during which you cannot manifest
  again — the "the Stand has to gather itself" beat.

### 3.2 Guard (timed parry)
- **Input:** block in the `ParryWindow` (default 0.25s) before an incoming melee hit lands.
- **Effect:** the Stand flickers in for a single beat, deflects the blow (attacker is staggered
  / shoved), and optionally fires a one-punch counter (a single NewProjectiles bolt).
- Feels like Star Platinum snapping out to catch a blade and snapping back.

### 3.3 Reflex (automatic save)
- **Trigger:** you take a hit at/above `ReflexHealthThreshold` of your max health *or* a hit
  that would drop you below `ReflexLethalGuard`, and you have Resolve banked.
- **Effect:** the Stand manifests for ~0.3s, negates a chunk of that hit (damage is partly
  refunded), and shoves the attacker. This is the spirit defending its user without being told.
- **Honesty:** because Skyrim's `OnHit` fires *after* damage is applied, the negation is
  modeled as an immediate partial heal + brief stagger-immunity, not a true pre-hit block.
  See `JJB_PlayerHitSensor.psc` notes.

### 3.4 Reach / precision (catch & pull)
- **Input:** precision input on a targeted object/actor/projectile within `ReachRange`.
- **Effect:** Stand reaches out (Star Finger / "catch") — pulls an item to hand, snatches a
  projectile out of the air, or yanks a target. One quick flicker.

---

## 4. Resolve (the spirit resource)

| Property               | Default | Meaning                                              |
|------------------------|---------|------------------------------------------------------|
| `ResolveMax`           | 100     | Cap.                                                 |
| `ResolveRegenPerSec`   | 12      | Regen while Dormant.                                 |
| `ResolveRegenDelay`    | 1.5s    | Pause after any manifestation before regen resumes.  |
| `CostBarragePerSec`    | 22      | Drain while a barrage is active.                     |
| `CostGuard`            | 15      | Flat cost per parry.                                 |
| `CostReflex`           | 25      | Flat cost per auto-save (and Reflex won’t fire below this). |
| `CostReach`            | 10      | Flat cost per reach.                                 |

Resolve is a `GlobalVariable` so it can be read by HUD widgets / SkyHUD / a meter mod, and
tuned live. A future MCM can expose all of the above.

---

## 5. Stand-Stance (intent, **not** visibility)

A toggle (default `X`) flips the user into **Stand-Stance**. This is purely an *intent*
signal and changes **nothing visible**:
- Enables the barrage/guard/reach inputs (out of stance, only Reflex can fire).
- Tightens the parry window slightly (you’re focused).
- Optionally slows the user’s movement a touch and changes the reticle.

The point: committing to your Stand is a stance of *readiness*, not a creature on the field.
This is the lever that keeps the OVA feel while still giving the player agency.

---

## 6. Per-Stand identity

Each Stand is defined in `data/StandDefs.json`. A definition pins:
- `barrageConfig` — which NewProjectiles JSON volley to fire (punch storm vs knife storm).
- `barrageHitSpell` — the hidden spell that the volley is built around (carries the MagicEffect).
- `guardCounterSpell` — optional single-bolt riposte.
- `reflexNegation` — % of the triggering hit refunded.
- `range` — `Melee` (Star Platinum, The World) vs `Ranged` (Hierophant Green, Magician’s Red).
- `actorBase` — the CK ActorBase used for the ghost mesh/skeleton.
- `manifestFx` / `dismissFx` — the flicker-in / flicker-out art (an Art Object or Effect Shader).
- `timeStop` (The World only) — see §7.

### Beta roster (Stardust Crusaders, OVA-appropriate)
| Stand            | User        | Range   | Signature window                                   |
|------------------|-------------|---------|----------------------------------------------------|
| Star Platinum    | (player)    | Melee   | Barrage rush, reflex catch, Star Finger reach      |
| The World        | (boss/NPC)  | Melee   | Barrage + **time-stop** finisher (see §7)          |
| Hierophant Green | (player/NPC)| Ranged  | Emerald Splash = NewProjectiles spread volley      |
| Silver Chariot   | (player/NPC)| Melee   | Rapier flurry = very tight, very fast barrage cone |

Only **Star Platinum** is fully wired in this beta; the others ship as data stubs + TODO.

---

## 7. The World — time-stop (stretch, OVA showpiece)
Time-stop is the marquee OVA moment. Implemented as a stretch goal:
- Freeze all non-user actors (disable AI / set to a frozen anim, drop time-scale globals).
- The user (or The World’s user) acts freely for `TimeStopDuration` seconds.
- Optional: drive the camera with the **CinematicCamera** DLL (`CinematicCamera.LoadAndLaunch`)
  for the "toki yo tomare" pan, then `CinematicCamera.Stop` on resume.
- Heavy/edge-case-prone — gated behind a flag and shipped disabled in beta.

---

## 8. Dependencies & boundaries

**Hard deps**
- This repo’s **NewProjectiles** framework (barrage/ranged volleys).
- SKSE64 (for key registration / robust timing).

**Soft deps**
- **CinematicCamera** (the uploaded DLL) — only for time-stop / finisher camera. Optional.
- A power-meter HUD mod to display the Resolve global. Optional.

**What lives in the Creation Kit (you build, I can’t generate here)**
- The ESP: quests, the bound-Stand ability/spell, keywords, the ghost ActorBase(s),
  art objects/shaders, sounds, the barrage hit spell + magic effect. All of it is enumerated
  in `ck-setup/FORMS.md`, each mapped to the exact script property it fills.

**What this folder gives you (text, committable, real)**
- The full design (this file).
- The Papyrus that implements the Flicker state machine and Resolve economy.
- The NewProjectiles JSON for the barrage/ranged volleys.
- The data schema for adding Stands.
- The CK build checklist.
