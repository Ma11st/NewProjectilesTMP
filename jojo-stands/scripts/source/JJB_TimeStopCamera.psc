Scriptname JJB_TimeStopCamera extends Quest
{ OPTIONAL camera wrapper for the time-stop showpiece. This is the ONLY script
  that touches the CinematicCamera mod, so the rest of JoJo Stands compiles even
  if CinematicCamera isn't installed -- just don't compile/attach this one, and
  leave JJB_StandManager.Camera as None.

  Attach to a small holder quest and point JJB_StandManager.Camera at it. }

; Begin the cinematic camera along a saved path (see CinematicCamera/settings.ini
; and the DemoPath that ships with that mod).
Function Begin(String asPath)
    If CinematicCamera.LoadAndLaunch(asPath)
        ; launched
    EndIf
EndFunction

Function End()
    CinematicCamera.Stop()
EndFunction
