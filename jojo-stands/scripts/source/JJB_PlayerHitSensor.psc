Scriptname JJB_PlayerHitSensor extends ReferenceAlias
{ Fill this alias with the player in the Stand quest. It watches for incoming
  hits and asks the controller whether the Stand should reflexively manifest
  to save its user (the OVA "Star Platinum blocks without being told" beat).

  HONESTY NOTE: Skyrim's OnHit fires AFTER damage is applied, so we cannot
  truly cancel the blow. TryReflex models the save as an immediate partial
  heal + brief stagger-immunity + a shove on the attacker. It reads close to a
  pre-hit block at speed, but it is a mitigation, not a true negation. }

JJB_StandController Property Controller Auto

; OnHit gives us source/projectile, not a damage number. We estimate the
; incoming damage so the controller can decide if it crosses the reflex
; threshold. Tune this multiplier per your damage mod.
Float Property MeleeDamageEstimate     = 30.0 Auto
Float Property ProjectileDamageEstimate = 22.0 Auto
Float Property PowerAttackMultiplier    = 2.0  Auto

Event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked)
    If !Controller || abHitBlocked
        return
    EndIf

    Actor attacker = akAggressor as Actor
    Float estimate
    If akProjectile
        estimate = ProjectileDamageEstimate
    Else
        estimate = MeleeDamageEstimate
    EndIf
    If abPowerAttack
        estimate *= PowerAttackMultiplier
    EndIf
    If abSneakAttack
        estimate *= 1.5
    EndIf

    Controller.TryReflex(estimate, attacker)
EndEvent
