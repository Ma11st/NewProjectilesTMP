Scriptname JJB_StandController extends Quest
{ Brain of the Stand system. Owns the bound Stand actor, the action windows
  (Barrage / Guard / Reflex / Reach), and the Resolve economy.

  This is the OVA "Flicker" model: the Stand is DORMANT (invisible/absent) by
  default and only manifests for the lifetime of a single action, then vanishes.
  There is intentionally NO persistent-summon function on this script. }

;======================================================================
; FORMS (fill these in the Creation Kit -- see ck-setup/FORMS.md)
;======================================================================

; The pre-placed, persistent, initially-DISABLED ghost actor that represents
; the Stand mesh. We never create/delete it at runtime, only show/hide it.
ObjectReference Property StandActor Auto
{ Persistent disabled actor used as the Stand's body. }

Spell Property BarrageSpell Auto
{ Hidden spell cast each barrage tick. NewProjectiles turns each cast into a
  fist cluster (see newprojectiles/JJB_StarPlatinum_Barrage.json). }

Spell Property GuardCounterSpell Auto
{ Optional single-bolt riposte fired on a successful parry. Can be None. }

Spell Property ReflexNegateSpell Auto
{ Self-cast on the player when Reflex fires: a brief heal + stagger-immunity
  that models the spirit "taking" part of the blow. }

EffectShader Property ManifestShader Auto
{ Flicker-in shader played on StandActor when it manifests. Can be None. }

EffectShader Property DismissShader Auto
{ Flicker-out shader. Can be None. }

Keyword Property HostileKeyword Auto
{ Used to validate Reach/Guard targets. Can be None. }

;======================================================================
; RESOLVE (the spirit resource) -- exposed as a global for HUD widgets
;======================================================================

GlobalVariable Property Resolve Auto
{ Current Resolve. Read by HUD mods; written by this script. }

Float Property ResolveMax          = 100.0 Auto
Float Property ResolveRegenPerSec  = 12.0  Auto
Float Property ResolveRegenDelay   = 1.5   Auto
Float Property CostBarragePerSec   = 22.0  Auto
Float Property CostGuard           = 15.0  Auto
Float Property CostReflex          = 25.0  Auto
Float Property CostReach           = 10.0  Auto

;======================================================================
; TUNING
;======================================================================

Float Property BarrageTickInterval = 0.12  Auto  ; seconds between fist clusters
Float Property BarrageMaxDuration  = 3.0   Auto
Float Property BarrageRecovery     = 0.6   Auto  ; "the spirit gathers itself"
Float Property GuardWindowSeconds  = 0.30  Auto  ; manifest duration for a parry
Float Property ReflexWindowSeconds = 0.30  Auto
Float Property ReachRange          = 512.0 Auto
Float Property ReflexHealthFrac    = 0.20  Auto  ; hit >= this frac of max HP triggers reflex
Float Property ManifestFadeTime    = 0.10  Auto

; Local offset (relative to the player) where the Stand flickers in.
Float Property OffsetForward = 70.0  Auto
Float Property OffsetRight   = 35.0  Auto
Float Property OffsetUp      = 0.0   Auto

;======================================================================
; STATE
;======================================================================

; 0 = Dormant, 1 = Barrage, 2 = Guard, 3 = Reflex
Int  property STATE_DORMANT = 0 autoReadonly
Int  property STATE_BARRAGE = 1 autoReadonly
Int  property STATE_GUARD   = 2 autoReadonly
Int  property STATE_REFLEX  = 3 autoReadonly

Int   _state = 0
Bool  _stance = false
Float _barrageElapsed = 0.0
Float _lastSpendTime = 0.0
Bool  _recovering = false

Actor _player

Event OnInit()
    _player = Game.GetPlayer()
    Resolve.SetValue(ResolveMax)
    _state = STATE_DORMANT
EndEvent

;======================================================================
; PUBLIC API (called by JJB_StandBondEffect / JJB_PlayerHitSensor)
;======================================================================

Bool Function IsStanceOn()
    return _stance
EndFunction

Function ToggleStance()
    _stance = !_stance
    If _stance
        Debug.Notification("Stand-Stance: ready")
    Else
        Debug.Notification("Stand-Stance: relaxed")
    EndIf
EndFunction

Int Function GetState()
    return _state
EndFunction

; ---- Barrage --------------------------------------------------------

Function BarrageStart()
    If _recovering || _state != STATE_DORMANT
        return
    EndIf
    If !_stance || GetResolve() < CostBarragePerSec * BarrageTickInterval
        return
    EndIf
    _state = STATE_BARRAGE
    _barrageElapsed = 0.0
    Manifest()
    PlayStandAnim("JJB_BarrageStart")
    ; Drive the barrage on its own update loop.
    RegisterForSingleUpdate(BarrageTickInterval)
EndFunction

Function BarrageStop()
    If _state != STATE_BARRAGE
        return
    EndIf
    UnregisterForUpdate()
    PlayStandAnim("JJB_BarrageStop")
    Dismiss()
    _state = STATE_DORMANT
    StartRecovery()
EndFunction

Event OnUpdate()
    ; Only the barrage uses the repeating update; everything else is one-shot.
    If _state != STATE_BARRAGE
        return
    EndIf

    _barrageElapsed += BarrageTickInterval
    Float cost = CostBarragePerSec * BarrageTickInterval

    If GetResolve() < cost || _barrageElapsed >= BarrageMaxDuration
        BarrageStop()
        return
    EndIf

    ; Each tick: one hidden cast -> NewProjectiles expands it into a fist cluster.
    SpendResolve(cost)
    BarrageSpell.Cast(_player, GetBarrageTarget())
    KeepStandPosed()
    RegisterForSingleUpdate(BarrageTickInterval)
EndEvent

; ---- Guard (timed parry) -------------------------------------------

Bool Function TryGuard()
    If _state != STATE_DORMANT || _recovering
        return false
    EndIf
    If !_stance || GetResolve() < CostGuard
        return false
    EndIf
    SpendResolve(CostGuard)
    _state = STATE_GUARD
    Manifest()
    PlayStandAnim("JJB_GuardCatch")
    If GuardCounterSpell
        GuardCounterSpell.Cast(_player, GetBarrageTarget())
    EndIf
    ; Single-beat window, then vanish.
    Utility.Wait(GuardWindowSeconds)
    Dismiss()
    _state = STATE_DORMANT
    StartRecovery()
    return true
EndFunction

; ---- Reflex (automatic save) ---------------------------------------
; Called by JJB_PlayerHitSensor.OnHit. Returns true if it fired.
Bool Function TryReflex(Float incomingDamage, Actor attacker)
    If _state != STATE_DORMANT || _recovering
        return false
    EndIf
    If GetResolve() < CostReflex
        return false
    EndIf
    Float trigger = _player.GetBaseActorValue("Health") * ReflexHealthFrac
    If incomingDamage < trigger
        return false
    EndIf

    SpendResolve(CostReflex)
    _state = STATE_REFLEX
    Manifest()
    PlayStandAnim("JJB_ReflexBlock")
    ; Model the "spirit takes the blow": refund part of the damage + shove attacker.
    If ReflexNegateSpell
        ReflexNegateSpell.Cast(_player, _player)
    EndIf
    If attacker
        attacker.PushActorAway(_player, 1.0)
    EndIf
    Utility.Wait(ReflexWindowSeconds)
    Dismiss()
    _state = STATE_DORMANT
    StartRecovery()
    return true
EndFunction

;======================================================================
; MANIFESTATION (flicker in / out) -- private
;======================================================================

Function Manifest()
    If !StandActor
        return
    EndIf
    KeepStandPosed()
    StandActor.SetAlpha(0.0, false)
    StandActor.Enable(false)
    If ManifestShader
        ManifestShader.Play(StandActor, ManifestFadeTime + 0.2)
    EndIf
    StandActor.SetAlpha(1.0, true)   ; fade in
EndFunction

Function Dismiss()
    If !StandActor
        return
    EndIf
    If DismissShader
        DismissShader.Play(StandActor, ManifestFadeTime + 0.2)
    EndIf
    StandActor.SetAlpha(0.0, true)   ; fade out
    Utility.Wait(ManifestFadeTime)
    StandActor.Disable(false)
EndFunction

; Snap the Stand to a point relative to the player, facing the same way.
Function KeepStandPosed()
    If !StandActor || !_player
        return
    EndIf
    Float a = _player.GetAngleZ()
    ; Papyrus Math.Sin/Cos take DEGREES, and GetAngleZ() returns degrees.
    Float fx = Math.sin(a) * OffsetForward + Math.cos(a) * OffsetRight
    Float fy = Math.cos(a) * OffsetForward - Math.sin(a) * OffsetRight
    StandActor.MoveTo(_player, fx, fy, OffsetUp)
    StandActor.SetAngle(0.0, 0.0, a)
EndFunction

Function PlayStandAnim(String asEvent)
    If StandActor
        Actor a = StandActor as Actor
        If a
            Debug.SendAnimationEvent(a, asEvent)
        EndIf
    EndIf
EndFunction

;======================================================================
; RESOLVE HELPERS -- private
;======================================================================

Float Function GetResolve()
    return Resolve.GetValue()
EndFunction

Function SpendResolve(Float amount)
    Float v = Resolve.GetValue() - amount
    If v < 0.0
        v = 0.0
    EndIf
    Resolve.SetValue(v)
    _lastSpendTime = Utility.GetCurrentRealTime()
EndFunction

; Called on a slow cadence by the bond effect to regenerate Resolve while Dormant.
Function RegenTick(Float deltaSeconds)
    If _state != STATE_DORMANT
        return
    EndIf
    If (Utility.GetCurrentRealTime() - _lastSpendTime) < ResolveRegenDelay
        return
    EndIf
    Float v = Resolve.GetValue() + ResolveRegenPerSec * deltaSeconds
    If v > ResolveMax
        v = ResolveMax
    EndIf
    Resolve.SetValue(v)
EndFunction

;======================================================================
; MISC -- private
;======================================================================

Function StartRecovery()
    _recovering = true
    Utility.Wait(BarrageRecovery)
    _recovering = false
EndFunction

; The barrage/guard target: the actor under the crosshair, else None
; (homing in the NewProjectiles config picks up the nearest hostile anyway).
Actor Function GetBarrageTarget()
    Actor t = _player.GetCombatTarget()
    return t
EndFunction
