Scriptname JJB_StandBondEffect extends ActiveMagicEffect
{ PER-ACTOR Stand brain. Applied as a constant-effect ability to whoever is bound
  to a Stand -- the player OR an enemy Stand user. Because each actor carries its
  own instance of this effect, each gets its own Stand, Resolve, and state machine
  (this is the per-actor refactor that replaces the old singleton controller).

  - The player instance reads input (keys) and uses the player's Resolve global +
    Mastery from the Manager.
  - An NPC instance is driven by simple combat AI and uses a local Resolve pool +
    the def's fixed Mastery.

  Requires SKSE (key registration) for the player. }

;======================================================================
; WIRING
;======================================================================
JJB_StandManager Property Manager Auto
JJB_StandDef     Property DefOverride Auto
{ For NPC users: which Stand this NPC has. Leave None on the player ability;
  the player's def comes from Manager.PlayerDef (set at awakening). }

Float Property RegenTickSeconds = 0.5 Auto
Float Property NpcThinkSeconds  = 0.75 Auto

;======================================================================
; STATE (per actor)
;======================================================================
Int Property STATE_DORMANT = 0 AutoReadOnly
Int Property STATE_BARRAGE = 1 AutoReadOnly
Int Property STATE_GUARD   = 2 AutoReadOnly
Int Property STATE_REFLEX  = 3 AutoReadOnly

Actor        _owner
Bool         _isPlayer
JJB_StandDef _def
ObjectReference _ghost

Int   _state = 0
Bool  _stance = false
Float _barrageElapsed = 0.0
Float _lastSpendTime = 0.0
Bool  _recovering = false
Float _resolveLocal = 100.0      ; NPC-only resolve pool
Float _lastHealth = 0.0          ; NPC-only, for health-drop reflex

; Effective (Mastery-adjusted) tunables, computed on bond start.
Float _effParryWindow
Float _effReachRange
Float _effBarrageInterval
Float _effBarrageCostPerSec

;======================================================================
; LIFECYCLE
;======================================================================
Event OnEffectStart(Actor akTarget, Actor akCaster)
    _owner = akTarget
    _isPlayer = (_owner == Game.GetPlayer())

    If _isPlayer
        _def = Manager.PlayerDef
    Else
        _def = DefOverride
    EndIf
    If !_def
        return   ; nothing to bind to
    EndIf

    ComputeEffectiveStats()
    SpawnGhost()
    _resolveLocal = Manager.ResolveMax
    _state = STATE_DORMANT

    If _isPlayer
        Manager.RegisterPlayerEffect(self)
        RebindKeys()
        RegisterForSingleUpdate(RegenTickSeconds)
    Else
        _stance = true                       ; NPCs are always "ready"
        RegisterForSingleUpdate(NpcThinkSeconds)
    EndIf
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
    UnregisterForUpdate()
    If _isPlayer
        UnregisterForAllKeys()
        Manager.ClearPlayerEffect()
    EndIf
    If _state == STATE_BARRAGE
        BarrageStop()
    EndIf
    DespawnGhost()
EndEvent

; Pull base tuning from the Manager, then apply this actor's Mastery as
; APPLICATION-only deltas (never raw power) -- see PROGRESSION S1.1.
Function ComputeEffectiveStats()
    Float precision = MasteryLevel(0)
    Float ferocity  = MasteryLevel(1)

    _effParryWindow       = Manager.GuardWindowSeconds + (precision / 100.0) * _def.PrecisionMaxParryBonus
    _effReachRange        = Manager.ReachRange         + (precision / 100.0) * _def.PrecisionMaxReachBonus
    _effBarrageInterval   = Manager.BarrageTickInterval - (ferocity / 100.0) * _def.FerocityMaxIntervalCut
    _effBarrageCostPerSec = Manager.CostBarragePerSec   - (ferocity / 100.0) * _def.FerocityMaxCostCut
    If _effBarrageInterval < 0.05
        _effBarrageInterval = 0.05
    EndIf
EndFunction

Float Function MasteryLevel(Int aiTrack)
    If _isPlayer
        If aiTrack == 0
            return Manager.GetPrecision()
        EndIf
        return Manager.GetFerocity()
    EndIf
    ; NPC: fixed levels from the def
    If aiTrack == 0
        return _def.NpcPrecision as Float
    EndIf
    return _def.NpcFerocity as Float
EndFunction

;======================================================================
; INPUT (player)
;======================================================================
; Re-register the player's hotkeys from the Manager (call after an MCM rebind).
Function RebindKeys()
    If !_isPlayer
        return
    EndIf
    UnregisterForAllKeys()
    RegisterForKey(Manager.BarrageKey)
    RegisterForKey(Manager.StanceKey)
    RegisterForKey(Manager.ReachKey)
    RegisterForKey(Manager.TimeStopKey)
EndFunction

Event OnKeyDown(Int keyCode)
    If !_def || Utility.IsInMenuMode()
        return
    EndIf
    If keyCode == Manager.StanceKey
        ToggleStance()
    ElseIf keyCode == Manager.BarrageKey
        BarrageStart()
    ElseIf keyCode == Manager.ReachKey
        TryReach()
    ElseIf keyCode == Manager.TimeStopKey
        TryTimeStop()
    EndIf
EndEvent

Event OnKeyUp(Int keyCode, Float holdTime)
    If keyCode == Manager.BarrageKey
        BarrageStop()
    EndIf
EndEvent

Function ToggleStance()
    _stance = !_stance
    If _stance
        Debug.Notification("Stand-Stance: ready")
    Else
        Debug.Notification("Stand-Stance: relaxed")
    EndIf
EndFunction

;======================================================================
; AI (NPC) + Resolve regen (player) share OnUpdate, branched by state
;======================================================================
Event OnUpdate()
    If _state == STATE_BARRAGE
        BarrageTick()
        return
    EndIf

    If _isPlayer
        RegenTick(RegenTickSeconds)
        RegisterForSingleUpdate(RegenTickSeconds)
    Else
        NpcThink()
        ; NpcThink may have started a barrage, which owns the update timer now.
        If _state != STATE_BARRAGE
            RegenTick(NpcThinkSeconds)
            RegisterForSingleUpdate(NpcThinkSeconds)
        EndIf
    EndIf
EndEvent

Function NpcThink()
    If !_owner.IsInCombat()
        _lastHealth = _owner.GetActorValue("Health")
        return
    EndIf

    ; NPC "reflex": magic effects get no OnHit, so detect a big health drop since
    ; the last think and manifest a guard reactively.
    Float hp = _owner.GetActorValue("Health")
    Float drop = _lastHealth - hp
    _lastHealth = hp
    If drop >= _owner.GetBaseActorValue("Health") * Manager.ReflexHealthFrac
        If TryReflex(drop, _owner.GetCombatTarget())
            return
        EndIf
    EndIf

    Actor t = _owner.GetCombatTarget()
    If !t
        return
    EndIf
    Float d = _owner.GetDistance(t)
    ; Close range -> barrage; mid range -> Star Finger reach if available.
    If _def.CanBarrage && d < 220.0 && GetResolve() > _effBarrageCostPerSec
        BarrageStart()
    ElseIf _def.CanReach && d < _effReachRange && GetResolve() > Manager.CostReach
        TryReach()
    EndIf
EndFunction

;======================================================================
; BARRAGE
;======================================================================
Function BarrageStart()
    If _recovering || _state != STATE_DORMANT || !_def.CanBarrage || !_def.BarrageSpell
        return
    EndIf
    If !_stance || GetResolve() < _effBarrageCostPerSec * _effBarrageInterval
        return
    EndIf
    _state = STATE_BARRAGE
    _barrageElapsed = 0.0
    Manifest()
    PlayStandAnim("JJB_BarrageStart")
    RegisterForSingleUpdate(_effBarrageInterval)
EndFunction

Function BarrageStop()
    If _state != STATE_BARRAGE
        return
    EndIf
    UnregisterForUpdate()
    PlayStandAnim("JJB_BarrageStop")
    Dismiss()
    _state = STATE_DORMANT
    If _isPlayer
        Manager.AddMastery(1, 1.5)   ; ferocity grows with committed rushes
    EndIf
    StartRecovery()
    RegisterForSingleUpdate(RegenTickSeconds)   ; resume regen loop
EndFunction

Function BarrageTick()
    _barrageElapsed += _effBarrageInterval
    Float cost = _effBarrageCostPerSec * _effBarrageInterval
    If GetResolve() < cost || _barrageElapsed >= Manager.BarrageMaxDuration
        BarrageStop()
        return
    EndIf
    SpendResolve(cost)
    _def.BarrageSpell.Cast(_owner, GetTarget())
    KeepGhostPosed()
    RegisterForSingleUpdate(_effBarrageInterval)
EndFunction

;======================================================================
; GUARD / REACH
;======================================================================
Bool Function TryGuard()
    If _state != STATE_DORMANT || _recovering || !_def.CanGuard
        return false
    EndIf
    If !_stance || GetResolve() < Manager.CostGuard
        return false
    EndIf
    SpendResolve(Manager.CostGuard)
    _state = STATE_GUARD
    Manifest()
    PlayStandAnim("JJB_GuardCatch")
    If _def.GuardCounterSpell
        _def.GuardCounterSpell.Cast(_owner, GetTarget())
    EndIf
    If _isPlayer
        Manager.AddMastery(0, 1.0)   ; precision grows with timed defense
    EndIf
    Utility.Wait(_effParryWindow)
    Dismiss()
    _state = STATE_DORMANT
    StartRecovery()
    return true
EndFunction

; Reach / Star Finger: one long-range strike (the Stand jabs out and snaps back).
Bool Function TryReach()
    If _state != STATE_DORMANT || _recovering || !_def.CanReach
        return false
    EndIf
    If !_stance || GetResolve() < Manager.CostReach
        return false
    EndIf
    SpendResolve(Manager.CostReach)
    _state = STATE_GUARD                 ; reuses the single-beat manifestation shell
    Manifest()
    PlayStandAnim("JJB_Reach")
    Spell strike = _def.ReachSpell
    If !strike
        strike = _def.GuardCounterSpell  ; fall back to the riposte bolt
    EndIf
    If strike
        strike.Cast(_owner, GetTarget())
    EndIf
    If _isPlayer
        Manager.AddMastery(0, 1.0)       ; precision
    EndIf
    Utility.Wait(_effParryWindow)
    Dismiss()
    _state = STATE_DORMANT
    StartRecovery()
    return true
EndFunction

; Brief time-stop (The World; Star Platinum once unlocked). Casts a cloak that
; freezes nearby non-users (JJB_FrozenEffect) and, optionally, drives the camera.
Bool Function TryTimeStop()
    If !_def.CanTimeStopBrief || !_def.TimeStopCloak
        return false
    EndIf
    If _state != STATE_DORMANT || _recovering
        return false
    EndIf
    ; Players must have unlocked it via Conviction + Mastery (Part-3 canon gate).
    If _isPlayer
        If Manager.Conviction.GetValue() < _def.TimeStopConvictionMin
            return false
        EndIf
        Float m = (MasteryLevel(0) + MasteryLevel(1)) / 2.0
        If m < _def.TimeStopMasteryMin
            return false
        EndIf
    EndIf
    Manifest()
    PlayStandAnim("JJB_TimeStop")
    Manager.DoTimeStop(_owner, _def.TimeStopCloak)
    Dismiss()
    return true
EndFunction

;======================================================================
; REFLEX (player: via JJB_PlayerHitSensor; NPC: via NpcThink health-drop)
;======================================================================
Bool Function TryReflex(Float incomingDamage, Actor attacker)
    If _state != STATE_DORMANT || _recovering
        return false
    EndIf
    If GetResolve() < Manager.CostReflex
        return false
    EndIf
    Float trigger = _owner.GetBaseActorValue("Health") * Manager.ReflexHealthFrac
    If incomingDamage < trigger
        return false
    EndIf

    SpendResolve(Manager.CostReflex)
    _state = STATE_REFLEX
    Manifest()
    PlayStandAnim("JJB_ReflexBlock")
    If _def.ReflexNegateSpell
        _def.ReflexNegateSpell.Cast(_owner, _owner)
    EndIf
    If attacker
        attacker.PushActorAway(_owner, 1.0)
    EndIf
    Utility.Wait(Manager.ReflexWindowSeconds)
    Dismiss()
    _state = STATE_DORMANT
    StartRecovery()
    return true
EndFunction

;======================================================================
; MANIFESTATION (flicker) -- spawns/uses this actor's own ghost
;======================================================================
Function SpawnGhost()
    If !_def.StandActorBase
        return
    EndIf
    _ghost = _owner.PlaceAtMe(_def.StandActorBase, 1, false, true)  ; persistent? no; disabled yes
    If _ghost && Manager.StandSightKeyword
        ; Mark the ghost so only Stand-users' AI can perceive it (PROGRESSION S6).
        ; (Keyword is applied via the ghost's ActorBase in the CK; this is a safety net.)
    EndIf
EndFunction

Function DespawnGhost()
    If _ghost
        _ghost.Disable(false)
        _ghost.Delete()
        _ghost = None
    EndIf
EndFunction

Function Manifest()
    If !_ghost
        return
    EndIf
    KeepGhostPosed()
    _ghost.SetAlpha(0.0, false)
    _ghost.Enable(false)
    If _def.ManifestShader
        _def.ManifestShader.Play(_ghost, Manager.ManifestFadeTime + 0.2)
    EndIf
    _ghost.SetAlpha(1.0, true)
EndFunction

Function Dismiss()
    If !_ghost
        return
    EndIf
    If _def.DismissShader
        _def.DismissShader.Play(_ghost, Manager.ManifestFadeTime + 0.2)
    EndIf
    _ghost.SetAlpha(0.0, true)
    Utility.Wait(Manager.ManifestFadeTime)
    _ghost.Disable(false)
EndFunction

Function KeepGhostPosed()
    If !_ghost || !_owner
        return
    EndIf
    Float a = _owner.GetAngleZ()
    ; Math.Sin/Cos take DEGREES; GetAngleZ returns degrees.
    Float fx = Math.sin(a) * Manager.OffsetForward + Math.cos(a) * Manager.OffsetRight
    Float fy = Math.cos(a) * Manager.OffsetForward - Math.sin(a) * Manager.OffsetRight
    _ghost.MoveTo(_owner, fx, fy, Manager.OffsetUp)
    _ghost.SetAngle(0.0, 0.0, a)
EndFunction

Function PlayStandAnim(String asEvent)
    Actor a = _ghost as Actor
    If a
        Debug.SendAnimationEvent(a, asEvent)
    EndIf
EndFunction

;======================================================================
; RESOLVE -- player uses the global, NPC uses a local pool
;======================================================================
Float Function GetResolve()
    If _isPlayer && Manager.Resolve
        return Manager.Resolve.GetValue()
    EndIf
    return _resolveLocal
EndFunction

Function SetResolve(Float v)
    If v < 0.0
        v = 0.0
    ElseIf v > Manager.ResolveMax
        v = Manager.ResolveMax
    EndIf
    If _isPlayer && Manager.Resolve
        Manager.Resolve.SetValue(v)
    Else
        _resolveLocal = v
    EndIf
EndFunction

Function SpendResolve(Float amount)
    SetResolve(GetResolve() - amount)
    _lastSpendTime = Utility.GetCurrentRealTime()
EndFunction

Function RegenTick(Float deltaSeconds)
    If _state != STATE_DORMANT
        return
    EndIf
    If (Utility.GetCurrentRealTime() - _lastSpendTime) < Manager.ResolveRegenDelay
        return
    EndIf
    SetResolve(GetResolve() + Manager.ResolveRegenPerSec * deltaSeconds)
EndFunction

;======================================================================
; MISC
;======================================================================
Function StartRecovery()
    _recovering = true
    Utility.Wait(Manager.BarrageRecovery)
    _recovering = false
EndFunction

Actor Function GetTarget()
    return _owner.GetCombatTarget()
EndFunction
