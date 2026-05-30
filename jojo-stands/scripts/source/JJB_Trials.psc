Scriptname JJB_Trials extends ReferenceAlias
{ Watches the player for "bravery" moments that represent a soul shift, and
  converts them into Conviction via Manager.GrantBreakthrough (PROGRESSION S1.2).

  Beta trials:
   - Clutch survival: end a fight you entered/finished after dropping below
     LowHpFraction of max health.
   - Outnumbered: win while 3+ enemies were engaged at once.
  Story-beat breakthroughs are granted directly from quest stages by calling
  Manager.GrantBreakthrough(...). }

JJB_StandManager Property Manager Auto

Float Property LowHpFraction      = 0.15 Auto
Int   Property OutnumberedCount   = 3    Auto
Float Property ClutchConviction   = 15.0 Auto
Float Property OutnumberedConviction = 10.0 Auto

Bool  _wentLow = false
Int   _peakEnemies = 0

Event OnCombatStateChanged(Actor akTarget, Int aeCombatState)
    Actor player = GetActorReference()
    If aeCombatState == 1            ; entered combat
        _wentLow = false
        _peakEnemies = CountNearbyHostiles(player)
    ElseIf aeCombatState == 0        ; left combat (survived -- we're not dead)
        EvaluateFight(player)
        _wentLow = false
        _peakEnemies = 0
    EndIf
EndEvent

; Called by JJB_PlayerHitSensor on each hit taken.
Function NoteDamageTaken()
    Actor player = GetActorReference()
    If !player
        return
    EndIf
    Float frac = player.GetActorValuePercentage("Health")
    If frac <= LowHpFraction
        _wentLow = true
    EndIf
    Int n = CountNearbyHostiles(player)
    If n > _peakEnemies
        _peakEnemies = n
    EndIf
EndFunction

Function EvaluateFight(Actor player)
    If !Manager
        return
    EndIf
    If _wentLow
        Manager.GrantBreakthrough("you stood firm at death's edge", ClutchConviction)
    EndIf
    If _peakEnemies >= OutnumberedCount
        Manager.GrantBreakthrough("you held against many", OutnumberedConviction)
    EndIf
EndFunction

; Lightweight headcount of hostiles currently in combat with the player.
Int Function CountNearbyHostiles(Actor player)
    If player && player.IsInCombat()
        ; A precise count needs an actor scan (PO3/PapyrusUtil) or a tracking alias
        ; collection; for the beta we treat "in combat" as at least 1 and let the
        ; outnumbered trial be wired to a CK alias-collection count if desired.
        return 1
    EndIf
    return 0
EndFunction
