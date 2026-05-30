Scriptname JJB_Awakening extends Quest
{ Drives the "your Stand awakens" scene + the soul-profile "personality test".
  Put this on the awakening quest. Your dialogue topic fragments then need only a
  ONE-LINER each, e.g.:

      (GetOwningQuest() as JJB_Awakening).Answer(0)     ; a Power answer
      (GetOwningQuest() as JJB_Awakening).Finish()      ; end the scene -> awaken

  Set Profile to the player ReferenceAlias that carries JJB_SoulProfile. }

JJB_SoulProfile Property Profile Auto
JJB_StandManager Property Manager Auto

Float Property PointsPerAnswer = 2.0 Auto

; Call from each dialogue answer. aiArchetype: 0=Power 1=Finesse 2=Control 3=Insight.
Function Answer(Int aiArchetype)
    If Profile
        Profile.AddArchetypePoints(aiArchetype, PointsPerAnswer)
    EndIf
EndFunction

; Call when the scene/dialogue ends. Resolves the archetype and awakens the Stand.
Function Finish()
    If Profile
        Profile.RunAwakening()
    ElseIf Manager
        Manager.AwakenPlayer(0)
    EndIf
EndFunction
