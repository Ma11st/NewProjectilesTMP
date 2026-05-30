Scriptname JJB_SoulProfile extends ReferenceAlias
{ Determines WHICH Stand the player awakens (PROGRESSION S4).

  Two inputs feed the same four archetype scores:
   1. Silent playstyle inference -- OnHit before awakening tallies how the player
      actually fights.
   2. The awakening dialogue -- each answer calls AddArchetypePoints(...).
  At the milestone, RunAwakening() picks the top archetype and asks the Manager
  to awaken the matching Stand.

  Archetypes: 0=Power 1=Finesse 2=Control 3=Insight. }

JJB_StandManager Property Manager Auto

; Set true once the player has their Stand; stops further passive tallying.
Bool _locked = false

Float _power   = 0.0
Float _finesse = 0.0
Float _control = 0.0
Float _insight = 0.0

; --- 1) passive playstyle inference ---------------------------------
Event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked)
    ; This alias is on the PLAYER, so OnHit here = the player being hit; we infer
    ; defensive style. Offensive style is inferred from the player's own attacks
    ; via a combat-event hook in the CK (or PapyrusUtil); for the beta, defense +
    ; the dialogue carry the weight.
    If _locked
        return
    EndIf
    If abHitBlocked
        _power += 1.0          ; stands its ground / blocks
    Else
        _finesse += 0.5        ; takes hits -> rewards evasive archetypes
    EndIf
EndEvent

; Call this from the player's weapon/spell swing events if you wire them (optional).
Function NoteAttack(Bool abRanged, Bool abMagic, Bool abSneak)
    If _locked
        return
    EndIf
    If abMagic
        _control += 1.0
    ElseIf abRanged
        _finesse += 1.0
    Else
        _power += 1.0
    EndIf
    If abSneak
        _finesse += 0.5
    EndIf
EndFunction

; --- 2) the awakening dialogue --------------------------------------
; Each dialogue answer calls this (set via the dialogue topic's script fragment).
Function AddArchetypePoints(Int aiArchetype, Float afAmount)
    If aiArchetype == 0
        _power += afAmount
    ElseIf aiArchetype == 1
        _finesse += afAmount
    ElseIf aiArchetype == 2
        _control += afAmount
    ElseIf aiArchetype == 3
        _insight += afAmount
    EndIf
EndFunction

; --- resolve + awaken -----------------------------------------------
Int Function ResolveArchetype()
    Int best = 0
    Float bestScore = _power
    If _finesse > bestScore
        best = 1
        bestScore = _finesse
    EndIf
    If _control > bestScore
        best = 2
        bestScore = _control
    EndIf
    If _insight > bestScore
        best = 3
        bestScore = _insight
    EndIf
    return best
EndFunction

; Call at the end of the awakening scene (quest stage / dialogue end).
Function RunAwakening()
    If _locked || !Manager
        return
    EndIf
    Int archetype = ResolveArchetype()
    Manager.AwakenPlayer(archetype)
    _locked = true
EndFunction
