Scriptname JJB_DebugAlias extends ReferenceAlias
{ Test harness. Put on a player ReferenceAlias in any Start-Game-Enabled quest.
  Gives you hotkeys to exercise the system without building the awakening quest:

    F9  -> awaken Star Platinum right now (or whatever DebugStandId is)
    F10 -> refill Resolve
    F8  -> +25 Conviction (to test evolution gates)
    F7  -> max Mastery (to test sub-ability unlocks)

  Leave it out of the final build, or gate Enabled behind a debug global. }

JJB_StandManager Property Manager Auto
String Property DebugStandId = "star_platinum" Auto

Int Property KeyAwaken      = 67 Auto   ; F9
Int Property KeyResolve     = 68 Auto   ; F10
Int Property KeyConviction  = 66 Auto   ; F8
Int Property KeyMastery     = 65 Auto   ; F7

Event OnInit()
    RegisterForKey(KeyAwaken)
    RegisterForKey(KeyResolve)
    RegisterForKey(KeyConviction)
    RegisterForKey(KeyMastery)
EndEvent

Event OnPlayerLoadGame()
    RegisterForKey(KeyAwaken)
    RegisterForKey(KeyResolve)
    RegisterForKey(KeyConviction)
    RegisterForKey(KeyMastery)
EndEvent

Event OnKeyDown(Int keyCode)
    If !Manager || Utility.IsInMenuMode()
        return
    EndIf
    If keyCode == KeyAwaken
        Manager.AwakenPlayerAs(DebugStandId)
    ElseIf keyCode == KeyResolve
        If Manager.Resolve
            Manager.Resolve.SetValue(Manager.ResolveMax)
            Debug.Notification("Resolve refilled.")
        EndIf
    ElseIf keyCode == KeyConviction
        Manager.GrantBreakthrough("debug", 25.0)
    ElseIf keyCode == KeyMastery
        Manager.AddMastery(0, 100.0)
        Manager.AddMastery(1, 100.0)
        Debug.Notification("Mastery maxed.")
    EndIf
EndEvent
