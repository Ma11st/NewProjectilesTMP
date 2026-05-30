# JoJo Stands — Progression, Acquisition & Evolution (design)

> Companion to [`DESIGN.md`](DESIGN.md). DESIGN.md covers the *moment-to-moment* feel
> (the Flicker manifestation model + Resolve). This file covers the **RPG layer**:
> how you get a Stand, how it grows, how it evolves, who else has one, and who can see it.
>
> **Status: design, not yet implemented.** The current branch ships the core-feel beta;
> this is the blueprint for the next code pass (which includes the per-actor controller
> refactor so enemy Stand users become possible).

---

## 0. OVA Canon Guardrails (hard constraint)

Everything below is bound by these rules so we stay on-track:

1. **Roster = Stardust Crusaders / OVA only** for now (Star Platinum, The World,
   Hierophant Green, Silver Chariot, Magician's Red, Hermit Purple, The Fool, etc.).
   No Stands from other Parts enter the *roster* until you say so.
2. **Stands behave per canon.** Creativity is allowed in *application and RPG framing*
   only — never in inventing tone-breaking powers. A Stand does what it did in the source.
3. **"Only certain Stands can do certain things"** is enforced in data, not vibes: each
   Stand carries a `capabilities` block (see §6). A close-range power can barrage; a
   ranged Stand can't; only The World (and, late, Star Platinum) touch time-stop. The code
   refuses any action a Stand isn't flagged for.
4. Mechanics that *describe* other-Part Stands (ACTs, Requiem) are built generically so the
   engine supports them, but they're only *wired* to canon-appropriate cases (e.g. Silver
   Chariot → Requiem, which is Polnareff — an SC character).

---

## 1. The three growth layers

| Layer | Scope | Grows from | Gates / affects | Lore reading |
|-------|-------|-----------|-----------------|--------------|
| **Resolve** | per-fight, short | regenerates while Dormant | fuels manifestations | spirit stamina |
| **Mastery** | per-Stand, persistent | *skillful, varied use* | **application** upgrades + sub-abilities | "a Stand is a muscle — practice sharpens it" |
| **Conviction** | per-user, persistent | **breakthrough milestones** | **form evolution** (ACT, Requiem) | the soul's growth / psychological shift |

The key separation you asked for: **Mastery never raises raw power — it improves
application** (tighter parry window, longer reach, faster barrage tracking, lower Resolve
costs, new *uses* of the same ability). **Conviction** is the rare, story-driven thing that
actually changes the Stand's *form/abilities*.

### 1.1 Mastery (use-driven, per Stand)
- Earned by *good* use, not spam: landing reflex saves, timed parries, precision reach
  catches, finishing with a barrage, defeating a stronger foe. (Spamming barrage into air
  earns almost nothing — anti-degeneracy.)
- Spent/auto-applied along per-Stand **Mastery tracks** declared in `StandDefs.json`. Each
  track unlocks *application* improvements and **sub-abilities** (§4).
- Because tracks are per-Stand data, **no two Stands progress the same way** — Star
  Platinum's tracks are about precision/speed; Hierophant Green's about range/zoning.

### 1.2 Conviction (milestone-driven, per user)
- A `GlobalVariable` raised only by **Breakthroughs** — discrete events representing a soul
  shift. A Breakthrough is granted by:
  - **Story beats** you author as quest stages (the dramatic moments), and/or
  - **Trials** — gameplay that *expresses* bravery/overcoming: win a fight that dropped you
    below 15% HP, defeat a higher-tier Stand user, protect an NPC and take zero damage,
    win while outnumbered 3+. A `JJB_Trials` watcher detects these and calls
    `GrantBreakthrough(reason)`.
- Conviction is the "supreme spiritual fortitude" gate for ACT and Requiem (§3). It is
  deliberately **not** farmable by grinding — it tracks meaningful moments.

---

## 2. Acquisition (milestone timing, both paths)

You said: getting a Stand is a **mid-game milestone**, via **both** canonical routes.

### 2.1 Awakening (bloodline / proximity) — the main milestone
A scripted, DIO's-resurrection-style event awakens the player's latent Stand mid-game
(authored as a main-quest stage). No risk of death — this is *your* awakening. The Stand you
get is chosen by the assignment system (§5).

### 2.2 The Arrow — the dangerous route (and double duty)
The meteorite **Arrow** is a rare item that pierces a *latent* person to draw out a Stand —
**lore-accurate: most die.** Using an Arrow on yourself/another runs a survival check
(gated by Conviction; low Conviction = likely death). Arrows are looted from defeated Stand
users or granted by a Speedwagon-Foundation-style faction, and they **gate content** (some
doors/NPCs only matter to users).

The same Arrow is also the **Requiem** catalyst at the top end (§3.3) — piercing an already
-awakened Stand at supreme Conviction evolves it instead of awakening a new one.

---

## 3. Evolution — four modes, per-Stand

All evolution data lives in each Stand's `evolution` block (§6). A Stand opts into only the
modes that fit its canon.

### 3.1 Mastery upgrades (application)
Covered in §1.1. Universal. Use-driven. Improves *how well* you wield the baseline.

### 3.2 ACT stages (form change)
- For Stands flagged `acts.supported`. Triggered by a **Breakthrough** at a specific
  Conviction threshold (and optionally a story flag). Swaps the active Stand to its next
  variant (a separate `StandDefs` entry: `<stand>_act2`, `_act3`), which can have different
  forms/abilities. The user can **switch back** to a prior ACT (intent toggle).
- *No Stardust Crusaders Stand uses ACTs canonically*, so this mode is **built but unwired**
  in the current roster — it exists for when you greenlight later Parts (Echoes, Tusk).
  Keeps us on-track today while not painting us into a corner.

### 3.3 Requiem (Arrow-into-Stand)
- For Stands flagged `requiem.supported`. Requires: **very high Conviction** + **high
  Mastery** + the **Arrow piercing the Stand itself** (a distinct ritual/event, not a normal
  Arrow use). Result: swaps to the `<stand>_requiem` variant — drastically stronger, new
  appearance, and **one signature ultimate "tailored to the user's deepest desire."**
- Canon-appropriate SC case: **Silver Chariot → Chariot Requiem** (Polnareff). Wired as the
  reference example. Endgame-rare.

### 3.4 Sub-abilities (emergent / desperation)
- For Stands with a `subAbilities` list. Two unlock styles:
  - **Mastery-gated:** revealed at a Mastery threshold (e.g. Star Platinum's **Star Finger**,
    or its late **brief time-stop** — which *is* Part-3 canon).
  - **Desperation-gated:** awakens the first time a desperation condition is met *and* the
    latent capacity exists (low HP / cornered) — the "Bites the Dust" pattern. Once awakened,
    it's permanent.
- These never change the Stand's form — they reveal new *applications* of its power.

---

## 4. Stand assignment — "which Stand is mine?" (the personality-test problem)

The concrete, no-magic-required mechanism. **Recommended: playstyle inference + a short
soul-profile dialogue.** Both feed the same four **archetype scores**:

| Archetype | Built from (pre-awakening) | Maps to (SC examples) |
|-----------|----------------------------|-----------------------|
| **Power** | melee hits, power attacks, blocking, 1-on-1 brawling | Star Platinum, The World |
| **Finesse** | ranged/bow, sneak, precise kills, kiting | Hierophant Green, Silver Chariot |
| **Control** | magic/utility, restoration, crowd control, support | Magician's Red, The Fool |
| **Insight** | exploration, lockpicking, detection, "knowing things" | Hermit Purple |

**How it actually works (all trivial in Skyrim):**
1. A quiet `JJB_SoulProfile` quest runs from game start, tallying combat/behavior events into
   four counters (pure `OnHit`/anim/skill-increase listeners). No UI.
2. At the **awakening** milestone, a short **dialogue scene** (3–5 questions via normal
   dialogue topics) nudges the scores — *this is your "personality test,"* implemented with
   vanilla dialogue + a scoring global. Example Q: *"They're cornered and outnumbered. You—"*
   → (charge in / find the angle / shield the weak / read the room) each adds to one archetype.
3. Highest archetype → an eligible SC Stand of that archetype. **Determinism is a flag:**
   - `deterministic`: highest score wins (predictable), or
   - `weightedRandom`: roll among the top archetypes (replayability).
4. Edge handling: ties broken by the dialogue answers; if you already hold a Stand, the Arrow
   path routes to Requiem (§3.3) instead of reassignment.

This is fully authorable: the questions, the mapping table, and determinism are all data you
control — so we can tune the "feel" without code changes.

---

## 5. Who else has Stands — enemy users (implemented)

- **Done:** the old singleton `JJB_StandController` is gone. Per-actor state now lives on
  **`JJB_StandBondEffect`** (an ActiveMagicEffect), so any actor carrying the bond ability
  gets its own Stand, Resolve, and state machine. An NPC ability variant just sets the
  effect's `DefOverride` to that NPC's Stand; the effect runs a simple combat-AI loop
  (`NpcThink`) that barrages in close range and parries reactively via a hit sensor.
- Each enemy user gets their own Resolve pool, their own StandDef, and their own Mastery
  (fixed per encounter via the def's `NpcPrecision/NpcFerocity`). Defeating them can drop
  Arrows and advance Conviction/Trials.

---

## 6. Who can *see* Stands (my call) — and why the Flicker model makes it nearly free

**Engine truth, stated plainly:** Skyrim rendering is global — you cannot truly render an
actor for one onlooker and hide it from another without heavy, fragile hacks. So we do the
*convincing* version, not the impossible one:

1. **The player always sees Stands** — correct, because the player is a Stand user.
2. **A `JJB_StandSight` keyword** marks who can *perceive* a manifested Stand. Only actors
   with it (Stand users) have AI that can detect/target the Stand actor.
3. **Non-users ignore the Stand entirely:** it's non-targetable to them, their packages don't
   react to it, and all damage/effects are **attributed to the Stand's user as the aggressor**
   — so from a non-user's side, "the guy hit me somehow," exactly the canon experience.
4. **The Flicker model does most of the work for free.** Because Stands are *already*
   invisible/absent except during a brief action window (DESIGN.md), there's barely any
   on-screen moment for a non-user to "see" one anyway. The OVA feel and the visibility rule
   reinforce each other.

Optional flavor toggle: a `StandBattleAura` that tints/distorts the scene only while a
manifestation is active and another user is present — sells "a battle only Stand users
perceive" without per-viewer rendering.

---

## 7. Build status

**Implemented in Papyrus (this pass):**
1. ✅ **Per-actor refactor** (`JJB_StandBondEffect`) — unblocks enemy users + multiple Stands.
2. ✅ **Resolve / Mastery / Conviction** (`JJB_StandManager`) + `GrantBreakthrough` + `JJB_Trials`.
3. ✅ **StandDef schema** (`capabilities` / mastery deltas / evolution) on `JJB_StandDef` +
   `data/StandDefs.json` v2.
4. ✅ **Assignment**: `JJB_SoulProfile` counters + awakening-dialogue scoring + archetype map.
5. ✅ **Acquisition hooks**: `Manager.AwakenPlayer()` + `Manager.TryRequiemRitual()` (the Arrow
   item/quest + survival check is CK work — see `ck-setup/FORMS.md` §6).
6. ◑ **Visibility**: `StandSightKeyword` plumbed; the perception/aggressor-reroute behavior is
   finished in the CK (keyword on ghost ActorBases + AI), plus the optional aura.

**Still ahead:**
- The **CK build** (`JoJoStands.esp`): def quests, abilities, ghost actors, dialogue, Arrow item.
- **ACT** form-switching flow (engine-supported via `NextActDef`, unwired for the SC roster).
- The World **time-stop**; ghost attack animations; an MCM.

ACTs stay built-but-unwired until later Parts are greenlit. Roster stays SC/OVA-only.
