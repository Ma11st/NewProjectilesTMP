Scriptname JJB_PlayerHitSensor extends ReferenceAlias
{ Fill this alias with the player. Watches incoming hits and asks the player's
  per-actor Stand brain (via the Manager) for a reflexive save -- the OVA
  "Star Platinum blocks without being told" beat. Also forwards damage to the
  Trials watcher so low-HP survival can earn a breakthrough.

  HONESTY NOTE: OnHit fires AFTER damage is applied, so we cannot truly cancel
  the blow. TryReflex models the save as a partial heal + brief stagger-immunity
  + a shove. It reads like a pre-hit block at speed, but it is mitigation. }

JJB_StandManager Property Manager Auto
JJB_Trials       Property Trials  Auto

Float Property MeleeDamageEstimate      = 30.0 Auto
Float Property ProjectileDamageEstimate = 22.0 Auto
Float Property PowerAttackMultiplier     = 2.0 Auto

Event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked)
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

    ; Feed the trials watcher (tracks the lowest HP fraction reached this fight).
    If Trials
        Trials.NoteDamageTaken()
    EndIf

    If abHitBlocked || !Manager || !Manager.IsAwakened()
        return
    EndIf
    JJB_StandBondEffect eff = Manager.GetPlayerEffect()
    If eff
        eff.TryReflex(estimate, attacker)
    EndIf
EndEvent
