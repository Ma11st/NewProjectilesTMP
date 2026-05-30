Scriptname JJB_FrozenEffect extends ActiveMagicEffect
{ The "time has stopped" effect, applied to every non-user actor caught in a
  Stand's time-stop spell (JJB_StandDef.TimeStopCloak -> a Self+Area fire-and-
  forget spell whose effect uses this script). The effect's DURATION (set in the
  CK) is how long that actor stays frozen.

  HONESTY: a true engine-wide time-stop needs an extender. This freezes each
  caught actor's movement and combat for the duration -- a faithful, vanilla-safe
  approximation. If powerofthree's Papyrus Extender is present, the EnableAI line
  (commented) gives a harder freeze. }

Event OnEffectStart(Actor akTarget, Actor akCaster)
    If akTarget == akCaster
        return                       ; never freeze the Stand user
    EndIf
    akTarget.SetDontMove(true)
    akTarget.SetRestrained(true)
    Debug.SendAnimationEvent(akTarget, "IdleForceDefaultState")
    ; With PapyrusExtender (PO3): akTarget.SetCommandState(0) / EnableAI(false)
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
    If akTarget == akCaster
        return
    EndIf
    akTarget.SetRestrained(false)
    akTarget.SetDontMove(false)
EndEvent
