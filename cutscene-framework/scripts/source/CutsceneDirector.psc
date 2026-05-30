Scriptname CutsceneDirector extends Quest
{ Plug-n-play cutscene layer on top of the CinematicCamera natives. Handles the
  boring parts -- fade in/out, freezing the player, hiding the HUD, and chaining
  on completion -- so a modder can run a cutscene in one call:

      Director.PlayCutscene("MyScene.json")
  or build one from markers placed in the CK:
      Director.PlayMarkers(myMarkerArray, 3.0, 75.0)

  Attach this to a quest and (optionally) fill the ImageSpaceModifier properties
  with the vanilla fade imods. }

;------------------------------------------------------------------
ImageSpaceModifier Property FadeOutImod Auto
{ Optional. e.g. FadeToBlackImod -- played at the start of a cutscene. }
ImageSpaceModifier Property FadeInImod Auto
{ Optional. e.g. FadeToBlackBackImod -- played when the cutscene ends. }
ImageSpaceModifier Property LetterboxImod Auto
{ Optional cinematic bars, applied for the duration. }

Bool Property DefaultFreeze = true Auto
{ Disable player controls + hide HUD during cutscenes by default. }

Float Property FadeSeconds = 0.5 Auto

Bool _running = false

;==================================================================
Event OnInit()
    RegisterForModEvent("CinematicCamera_OnFinish", "OnCCFinish")
EndEvent

Event OnPlayerLoadGame()
    RegisterForModEvent("CinematicCamera_OnFinish", "OnCCFinish")
    ; safety: never stay stuck in a cutscene across a load
    If _running
        _End()
    EndIf
EndEvent

;==================================================================
; Play a cutscene from a JSON path file.
Function PlayCutscene(String asPathFile, Bool abFreeze = true)
    If _running
        return
    EndIf
    _Begin(abFreeze)
    If !CinematicCamera.LoadAndLaunch(asPathFile)
        Debug.Trace("CutsceneDirector: failed to load " + asPathFile)
        _End()
    EndIf
EndFunction

; Play a path you've already built via CinematicCamera.BeginPath/AddKeyframe.
Function PlayBuiltCutscene(Bool abFreeze = true)
    If _running
        return
    EndIf
    _Begin(abFreeze)
    CinematicCamera.LaunchBuiltPath()
EndFunction

; Build a cutscene from CK markers (uses each marker's position + angles), giving
; each marker afSecondsEach of travel. fov <= 0 leaves FOV alone.
Function PlayMarkers(ObjectReference[] akMarkers, Float afSecondsEach = 3.0, Float afFov = 0.0, Bool abFreeze = true)
    If _running || akMarkers.Length == 0
        return
    EndIf
    CinematicCamera.BeginPath()
    Int i = 0
    While i < akMarkers.Length
        ObjectReference m = akMarkers[i]
        If m
            Float t = i * afSecondsEach
            CinematicCamera.AddKeyframe(t, m.GetPositionX(), m.GetPositionY(), m.GetPositionZ(), m.GetAngleX(), 0.0, m.GetAngleZ(), afFov)
        EndIf
        i += 1
    EndWhile
    _Begin(abFreeze)
    CinematicCamera.LaunchBuiltPath()
EndFunction

; Stop early.
Function StopCutscene()
    If !_running
        return
    EndIf
    CinematicCamera.Stop()
    _End()
EndFunction

;==================================================================
Event OnCCFinish(String asEvent, String asStr, Float afNum, Form akSender)
    If _running
        _End()
    EndIf
EndEvent

;==================================================================
Function _Begin(Bool abFreeze)
    _running = true
    If FadeOutImod
        FadeOutImod.ApplyCrossFade(FadeSeconds)
    EndIf
    If LetterboxImod
        LetterboxImod.Apply()
    EndIf
    If abFreeze || DefaultFreeze
        Game.DisablePlayerControls(true, true, false, false, true, true, true, false, 0)
        Utility.SetINIBool("bShowCompass:Interface", false)
    EndIf
EndFunction

Function _End()
    _running = false
    If LetterboxImod
        LetterboxImod.PopTo(FadeInImod)
    ElseIf FadeInImod
        FadeInImod.ApplyCrossFade(FadeSeconds)
    EndIf
    Game.EnablePlayerControls(true, true, true, true, true, true, true, true, 0)
    Utility.SetINIBool("bShowCompass:Interface", true)
EndFunction
