Scriptname JJB_StandBondEffect extends ActiveMagicEffect
{ The "you have a Stand" bond. Applied to the player as a constant-effect
  ability (from a perk, a quest, or the Arrow-to-the-knee event that grants a
  Stand). This is the INPUT layer: it captures the barrage / stance / reach
  keys and runs the slow Resolve regen tick. All real work is delegated to
  JJB_StandController so the rules live in one place.

  Requires SKSE (RegisterForKey / OnKeyDown / OnKeyUp). }

JJB_StandController Property Controller Auto
{ The central controller quest. }

; DXScancodes (https://wiki.nexusmods.com/index.php/DirectX_Scancodes...).
; Defaults mirror the OVA feel: Q = rush, X = ready-stance, F = reach.
Int Property BarrageKey = 16 Auto   ; Q
Int Property StanceKey  = 45 Auto   ; X
Int Property ReachKey   = 33 Auto   ; F

Float Property RegenTickSeconds = 0.5 Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    RegisterForKey(BarrageKey)
    RegisterForKey(StanceKey)
    RegisterForKey(ReachKey)
    RegisterForSingleUpdate(RegenTickSeconds)
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
    UnregisterForAllKeys()
    UnregisterForUpdate()
    ; Safety: if the bond is lost mid-barrage, make sure the Stand is dismissed.
    If Controller && Controller.GetState() == Controller.STATE_BARRAGE
        Controller.BarrageStop()
    EndIf
EndEvent

Event OnKeyDown(Int keyCode)
    If !Controller
        return
    EndIf
    ; Don't eat keys while a menu/console is open.
    If Utility.IsInMenuMode()
        return
    EndIf

    If keyCode == StanceKey
        Controller.ToggleStance()
    ElseIf keyCode == BarrageKey
        Controller.BarrageStart()
    ElseIf keyCode == ReachKey
        ; Reach reuses the Guard manifestation shell with a catch payload.
        Controller.TryGuard()
    EndIf
EndEvent

Event OnKeyUp(Int keyCode, Float holdTime)
    If !Controller
        return
    EndIf
    If keyCode == BarrageKey
        Controller.BarrageStop()
    EndIf
EndEvent

; Slow background loop: regenerate Resolve while Dormant.
Event OnUpdate()
    If Controller
        Controller.RegenTick(RegenTickSeconds)
    EndIf
    RegisterForSingleUpdate(RegenTickSeconds)
EndEvent
