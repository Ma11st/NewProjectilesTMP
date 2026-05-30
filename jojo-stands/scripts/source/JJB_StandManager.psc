Scriptname JJB_StandManager extends Quest
{ Singleton. Owns global tuning, the Stand-def registry, the PLAYER's long-term
  progression (Conviction + Mastery), and the awakening/evolution glue.

  Per-actor combat state does NOT live here (that was the old singleton that
  blocked enemy users). It now lives on each actor's JJB_StandBondEffect. }

;======================================================================
; REGISTRY
;======================================================================
JJB_StandDef[] Property Defs Auto
{ Every JJB_StandDef quest (player + NPC + variants). }

JJB_StandDef Function GetDefById(String asId)
    Int i = 0
    While i < Defs.Length
        If Defs[i] && Defs[i].StandId == asId
            return Defs[i]
        EndIf
        i += 1
    EndWhile
    return None
EndFunction

; First non-variant def of an archetype (assignment fallback).
JJB_StandDef Function GetDefByArchetype(Int aiArchetype)
    Int i = 0
    While i < Defs.Length
        If Defs[i] && !Defs[i].IsVariant && Defs[i].Archetype == aiArchetype
            return Defs[i]
        EndIf
        i += 1
    EndWhile
    return None
EndFunction

;======================================================================
; GLOBAL TUNING (was on the old controller; shared by every instance)
;======================================================================
Float Property ResolveMax          = 100.0 Auto
Float Property ResolveRegenPerSec  = 12.0  Auto
Float Property ResolveRegenDelay   = 1.5   Auto
Float Property CostBarragePerSec   = 22.0  Auto
Float Property CostGuard           = 15.0  Auto
Float Property CostReflex          = 25.0  Auto
Float Property CostReach           = 10.0  Auto

Float Property BarrageTickInterval = 0.12  Auto
Float Property BarrageMaxDuration  = 3.0   Auto
Float Property BarrageRecovery     = 0.6   Auto
Float Property GuardWindowSeconds  = 0.30  Auto
Float Property ReflexWindowSeconds = 0.30  Auto
Float Property ReachRange          = 512.0 Auto
Float Property ReflexHealthFrac    = 0.20  Auto
Float Property ManifestFadeTime    = 0.10  Auto
Float Property OffsetForward       = 70.0  Auto
Float Property OffsetRight         = 35.0  Auto
Float Property OffsetUp            = 0.0   Auto

; Player keybinds (DXScancodes). Authoritative here so the MCM can rebind live.
Int Property BarrageKey = 16 Auto   ; Q
Int Property StanceKey  = 45 Auto   ; X
Int Property ReachKey   = 33 Auto   ; F
Int Property TimeStopKey = 19 Auto  ; R (only fires if the Stand can time-stop)

;======================================================================
; PLAYER LONG-TERM PROGRESSION
;======================================================================
GlobalVariable Property Resolve     Auto  ; player's live Resolve (HUD-readable)
GlobalVariable Property Conviction  Auto  ; soul growth; gates evolution

Spell    Property StandBondAbility Auto   ; the constant-effect ability granted on awakening
Keyword  Property StandSightKeyword Auto  ; perception gate (visibility, see PROGRESSION S6)

JJB_StandDef Property PlayerDef Auto       ; the player's current Stand (set on awakening)
Float _playerPrecision = 0.0
Float _playerFerocity  = 0.0
Bool  _awakened = false

JJB_StandBondEffect _playerEffect          ; live handle to the player's per-actor brain

Event OnInit()
    If Resolve
        Resolve.SetValue(ResolveMax)
    EndIf
EndEvent

; The player's bond effect registers itself here so the hit sensor can reach it.
Function RegisterPlayerEffect(JJB_StandBondEffect akEffect)
    _playerEffect = akEffect
EndFunction
Function ClearPlayerEffect()
    _playerEffect = None
EndFunction
JJB_StandBondEffect Function GetPlayerEffect()
    return _playerEffect
EndFunction

Bool Function IsAwakened()
    return _awakened
EndFunction

; --- Mastery (player) -----------------------------------------------
Float Function GetPrecision()
    return _playerPrecision
EndFunction
Float Function GetFerocity()
    return _playerFerocity
EndFunction

; track: 0 = Precision, 1 = Ferocity. Mastery rewards skillful use only.
Function AddMastery(Int aiTrack, Float afAmount)
    If aiTrack == 0
        _playerPrecision = ClampMastery(_playerPrecision + afAmount)
    Else
        _playerFerocity = ClampMastery(_playerFerocity + afAmount)
    EndIf
EndFunction

Float Function ClampMastery(Float v)
    If v < 0.0
        return 0.0
    ElseIf v > 100.0
        return 100.0
    EndIf
    return v
EndFunction

;======================================================================
; CONVICTION / BREAKTHROUGHS (gates form evolution)
;======================================================================
Function GrantBreakthrough(String asReason, Float afAmount = 15.0)
    If !Conviction
        return
    EndIf
    Conviction.SetValue(Conviction.GetValue() + afAmount)
    Debug.Notification("A breakthrough: " + asReason)
    CheckEvolution()
EndFunction

; Offer ACT/Requiem if the player's Stand qualifies. Requiem also needs the ritual
; (Arrow-into-Stand) which is triggered separately by TryRequiemRitual().
Function CheckEvolution()
    If !PlayerDef
        return
    EndIf
    If PlayerDef.ActsSupported && PlayerDef.NextActDef
        ; Form change is a deliberate moment; surface it, let the player accept.
        Debug.Notification(PlayerDef.DisplayName + " stirs... (ACT available)")
    EndIf
EndFunction

; Called by the Arrow's "pierce your own Stand" ritual.
Bool Function TryRequiemRitual()
    If !PlayerDef || !PlayerDef.RequiemSupported || !PlayerDef.RequiemDef
        return false
    EndIf
    If Conviction.GetValue() < PlayerDef.RequiemConvictionMin
        return false
    EndIf
    Float m = (_playerPrecision + _playerFerocity) / 2.0
    If m < PlayerDef.RequiemMasteryMin
        return false
    EndIf
    SwitchPlayerDef(PlayerDef.RequiemDef)
    Debug.Notification(PlayerDef.DisplayName + " REQUIEM!")
    return true
EndFunction

; Swap the active Stand form (ACT/Requiem). Mastery is preserved across the lineage.
Function SwitchPlayerDef(JJB_StandDef akNewDef)
    If akNewDef
        PlayerDef = akNewDef
    EndIf
EndFunction

;======================================================================
; AWAKENING (the mid-game milestone)
;======================================================================
; Called by the awakening quest stage. aiArchetype comes from JJB_SoulProfile.
Function AwakenPlayer(Int aiArchetype)
    If _awakened
        return
    EndIf
    JJB_StandDef def = GetDefByArchetype(aiArchetype)
    If !def
        def = GetDefById("star_platinum")   ; safe fallback
    EndIf
    PlayerDef = def
    _awakened = true
    If Resolve
        Resolve.SetValue(ResolveMax)
    EndIf
    If StandBondAbility
        Game.GetPlayer().AddSpell(StandBondAbility, false)
    EndIf
    Debug.Notification("Your Stand awakens: " + def.DisplayName)
EndFunction

; Debug / scripted: awaken a specific Stand by id regardless of archetype.
Function AwakenPlayerAs(String asStandId)
    JJB_StandDef def = GetDefById(asStandId)
    If !def
        return
    EndIf
    PlayerDef = def
    _awakened = true
    If Resolve
        Resolve.SetValue(ResolveMax)
    EndIf
    If StandBondAbility && !Game.GetPlayer().HasSpell(StandBondAbility)
        Game.GetPlayer().AddSpell(StandBondAbility, false)
    EndIf
    Debug.Notification("Your Stand awakens: " + def.DisplayName)
EndFunction

;======================================================================
; THE ARROW (survival check) -- used by JJB_ArrowEffect
;======================================================================
Float Property ArrowBaseSurvival   = 0.10 Auto  ; 10% at zero Conviction (most die)
Float Property ArrowConvictionScale = 0.009 Auto ; +0.9% survival per Conviction point

Bool Function ArrowSurvives()
    Float chance = ArrowBaseSurvival
    If Conviction
        chance += Conviction.GetValue() * ArrowConvictionScale
    EndIf
    If chance > 0.95
        chance = 0.95
    EndIf
    return Utility.RandomFloat(0.0, 1.0) <= chance
EndFunction

;======================================================================
; TIME-STOP (brief) -- casts the def's freeze cloak; optional camera
;======================================================================
Float Property TimeStopDuration = 5.0 Auto
String Property TimeStopCameraPath = "Data/SKSE/Plugins/CinematicCamera/DemoPath" Auto
JJB_TimeStopCamera Property Camera Auto
{ Optional. If set (and CinematicCamera is installed), drives the camera during the stop. }

Function DoTimeStop(Actor akCaster, Spell akCloak)
    If !akCaster || !akCloak
        return
    EndIf
    ; akCloak is a fire-and-forget Self spell with a large Area; its JJB_FrozenEffect
    ; thus applies to every non-caster actor in range for its (CK-set) duration.
    akCloak.Cast(akCaster, akCaster)
    Debug.Notification("Toki yo tomare! Time has stopped.")
    If Camera
        Camera.Begin(TimeStopCameraPath)
    EndIf
EndFunction

; Called by JJB_FrozenEffect on the LAST frozen actor, or by a timer, to end the stop.
Function EndTimeStop()
    If Camera
        Camera.End()
    EndIf
EndFunction
