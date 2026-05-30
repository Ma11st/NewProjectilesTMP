Scriptname JJB_ArrowEffect extends ActiveMagicEffect
{ The Stand Arrow. Delivered as a lesser power / spell "Pierce yourself with the
  Arrow" (Delivery: Self) carrying this effect -- or cast on an NPC to try to make
  them a Stand user.

  Rules (PROGRESSION S2.2):
   - If the target already has a Stand -> attempt Requiem (Arrow-into-Stand).
   - Otherwise run a survival check gated by Conviction. Most people die.
   - Survive + you're the player -> awaken (archetype from the soul profile).

  Wiring: set Manager + Profile. The granting item should be single-use (remove a
  MiscObject "The Arrow" on use, or it's a one-shot quest reward power). }

JJB_StandManager Property Manager Auto
JJB_SoulProfile  Property Profile Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    If !Manager
        return
    EndIf
    Bool isPlayer = (akTarget == Game.GetPlayer())

    ; Already a Stand user -> this is a Requiem attempt, not a new awakening.
    If isPlayer && Manager.IsAwakened()
        If Manager.TryRequiemRitual()
            ; success handled inside (form swap + notify)
        Else
            Debug.Notification("The Arrow pierces your Stand... but nothing answers. (Not enough resolve.)")
        EndIf
        return
    EndIf

    ; Latent target: survive or die.
    If !Manager.ArrowSurvives()
        Debug.Notification("The Arrow's power is too much to bear...")
        akTarget.Kill()   ; most who are pierced do not survive
        return
    EndIf

    If isPlayer
        If Profile
            Profile.RunAwakening()
        Else
            Manager.AwakenPlayer(0)
        EndIf
    Else
        ; NPC awakening is rare/encounter-authored; flag it for your quest to handle.
        Debug.Notification(akTarget.GetDisplayName() + " survives the Arrow.")
    EndIf
EndEvent
