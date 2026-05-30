Scriptname JJB_StandDef extends Quest
{ Static, read-only data for ONE Stand. Create one quest per Stand in the CK
  (JJB_Def_StarPlatinum, JJB_Def_HierophantGreen, ...) and fill these properties.

  This is the runtime mirror of an entry in data/StandDefs.json. Papyrus can't
  read JSON without an extender, so StandDefs.json is the design source-of-truth
  and these quests are what the game actually reads. ck-setup/FORMS.md maps the
  two. Nothing here changes at runtime. }

;--- Identity -------------------------------------------------------
String  Property StandId   Auto   ; e.g. "star_platinum" (must match StandDefs.json)
Int     Property Archetype Auto    ; 0=Power 1=Finesse 2=Control 3=Insight
Bool    Property IsVariant Auto    ; true for an ACT/Requiem form
String  Property DisplayName Auto

;--- Capability gating (OVA guardrail: code refuses anything false) -
Bool Property CanBarrage       = false Auto
Bool Property CanGuard         = false Auto
Bool Property CanReach         = false Auto
Bool Property CanRanged        = false Auto
Bool Property CanTimeStopBrief = false Auto

;--- Forms (filled in CK) -------------------------------------------
ActorBase    Property StandActorBase    Auto  ; the ghost body spawned per user
Spell        Property BarrageSpell       Auto  ; hidden, cast each barrage tick
Spell        Property RangedSpell        Auto  ; ranged volley (Emerald Splash etc.)
Spell        Property ReachSpell         Auto  ; single long strike (Star Finger)
Spell        Property GuardCounterSpell  Auto
Spell        Property ReflexNegateSpell  Auto
Spell        Property TimeStopCloak      Auto  ; cloak that freezes nearby non-users (The World / SP)
EffectShader Property ManifestShader     Auto
EffectShader Property DismissShader      Auto

Float Property ReflexNegationFrac = 0.5 Auto  ; share of the hit refunded on Reflex

;--- Mastery (application-only deltas, scaled 0..1 by track level) ---
; Effective stat = base (from Manager) +/- (level/100) * maxDelta.
Float Property PrecisionMaxParryBonus = 0.10  Auto  ; + seconds at 100 Precision
Float Property PrecisionMaxReachBonus = 256.0 Auto  ; + units at 100 Precision
Float Property FerocityMaxIntervalCut = 0.04  Auto  ; - seconds at 100 Ferocity
Float Property FerocityMaxCostCut     = 8.0   Auto  ; - resolve/s at 100 Ferocity

; Sub-ability unlock thresholds (see StandDefs.json subAbilities).
Int Property StarFingerPrecisionMin = 60 Auto   ; Reach distance spike
Int Property TimeStopConvictionMin  = 90 Auto   ; SP brief time-stop (Part-3 canon)
Int Property TimeStopMasteryMin     = 95 Auto

;--- NPC users: fixed mastery levels (player's are stored on Manager) ---
Int Property NpcPrecision = 40 Auto
Int Property NpcFerocity  = 40 Auto

;--- Evolution links ------------------------------------------------
Bool        Property ActsSupported    = false Auto
JJB_StandDef Property NextActDef        Auto    ; switch-to on ACT breakthrough
Bool        Property RequiemSupported = false Auto
JJB_StandDef Property RequiemDef        Auto    ; switch-to on Requiem ritual
Int         Property RequiemConvictionMin = 95 Auto
Int         Property RequiemMasteryMin    = 90 Auto

; Capability check by name, so callers stay generic.
Bool Function Allows(String asAction)
    If asAction == "barrage"
        return CanBarrage
    ElseIf asAction == "guard"
        return CanGuard
    ElseIf asAction == "reach"
        return CanReach
    ElseIf asAction == "ranged"
        return CanRanged
    ElseIf asAction == "timestop"
        return CanTimeStopBrief
    EndIf
    return false
EndFunction
