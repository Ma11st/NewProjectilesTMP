Scriptname JJB_MCM extends SKI_ConfigBase
{ Mod Configuration Menu for JoJo Stands. OPTIONAL -- requires SkyUI. If you don't
  use SkyUI, just don't compile/attach this script; everything else is unaffected.

  Attach to a quest (Start Game Enabled) and set Manager. SkyUI registers it. }

JJB_StandManager Property Manager Auto

; --- option id stores -------------------------------------------------
Int _oAwaken
Int _oRefill
Int _oConviction
Int _oResolveMax
Int _oRegen
Int _oBarrageCost
Int _oBarrageDur
Int _oBarrageInt
Int _oReachRange
Int _kBarrage
Int _kStance
Int _kReach
Int _kTimeStop

Event OnConfigInit()
    ModName = "JoJo Stands"
    Pages = new String[3]
    Pages[0] = "Status"
    Pages[1] = "Controls"
    Pages[2] = "Tuning"
EndEvent

Event OnPageReset(String page)
    If page == "Status" || page == ""
        BuildStatusPage()
    ElseIf page == "Controls"
        BuildControlsPage()
    ElseIf page == "Tuning"
        BuildTuningPage()
    EndIf
EndEvent

;======================================================================
Function BuildStatusPage()
    SetCursorFillMode(TOP_TO_BOTTOM)
    AddHeaderOption("Stand")
    String standName = "(none)"
    If Manager.PlayerDef
        standName = Manager.PlayerDef.DisplayName
    EndIf
    AddTextOption("Current Stand", standName)
    AddTextOption("Awakened", BoolStr(Manager.IsAwakened()))

    AddHeaderOption("Energy & Growth")
    AddTextOption("Resolve", FloatStr(GetGlobal(Manager.Resolve)) + " / " + (Manager.ResolveMax as Int))
    AddTextOption("Conviction", FloatStr(GetGlobal(Manager.Conviction)))
    AddTextOption("Precision", "" + (Manager.GetPrecision() as Int) + " / 100")
    AddTextOption("Ferocity", "" + (Manager.GetFerocity() as Int) + " / 100")

    AddHeaderOption("Debug")
    _oAwaken     = AddTextOption("Awaken Star Platinum (test)", "")
    _oRefill     = AddTextOption("Refill Resolve", "")
    _oConviction = AddTextOption("+25 Conviction", "")
EndFunction

Function BuildControlsPage()
    SetCursorFillMode(TOP_TO_BOTTOM)
    AddHeaderOption("Hotkeys")
    _kBarrage  = AddKeyMapOption("Barrage (hold)", Manager.BarrageKey)
    _kStance   = AddKeyMapOption("Stand-Stance", Manager.StanceKey)
    _kReach    = AddKeyMapOption("Reach / Star Finger", Manager.ReachKey)
    _kTimeStop = AddKeyMapOption("Time-Stop (if unlocked)", Manager.TimeStopKey)
EndFunction

Function BuildTuningPage()
    SetCursorFillMode(TOP_TO_BOTTOM)
    AddHeaderOption("Resolve")
    _oResolveMax   = AddSliderOption("Resolve Max", Manager.ResolveMax, "{0}")
    _oRegen        = AddSliderOption("Regen / sec", Manager.ResolveRegenPerSec, "{1}")
    AddHeaderOption("Barrage")
    _oBarrageCost  = AddSliderOption("Cost / sec", Manager.CostBarragePerSec, "{1}")
    _oBarrageDur   = AddSliderOption("Max Duration", Manager.BarrageMaxDuration, "{2}")
    _oBarrageInt   = AddSliderOption("Tick Interval", Manager.BarrageTickInterval, "{2}")
    AddHeaderOption("Reach")
    _oReachRange   = AddSliderOption("Reach Range", Manager.ReachRange, "{0}")
EndFunction

;======================================================================
Event OnOptionSelect(Int option)
    If option == _oAwaken
        Manager.AwakenPlayerAs("star_platinum")
        ForcePageReset()
    ElseIf option == _oRefill
        If Manager.Resolve
            Manager.Resolve.SetValue(Manager.ResolveMax)
        EndIf
        ForcePageReset()
    ElseIf option == _oConviction
        Manager.GrantBreakthrough("MCM", 25.0)
        ForcePageReset()
    EndIf
EndEvent

Event OnOptionKeyMapChange(Int option, Int keyCode, String conflict, String conflictName)
    If option == _kBarrage
        Manager.BarrageKey = keyCode
        SetKeyMapOptionValue(_kBarrage, keyCode)
    ElseIf option == _kStance
        Manager.StanceKey = keyCode
        SetKeyMapOptionValue(_kStance, keyCode)
    ElseIf option == _kReach
        Manager.ReachKey = keyCode
        SetKeyMapOptionValue(_kReach, keyCode)
    ElseIf option == _kTimeStop
        Manager.TimeStopKey = keyCode
        SetKeyMapOptionValue(_kTimeStop, keyCode)
    EndIf
    JJB_StandBondEffect eff = Manager.GetPlayerEffect()
    If eff
        eff.RebindKeys()
    EndIf
EndEvent

Event OnOptionSliderOpen(Int option)
    If option == _oResolveMax
        OpenSlider(Manager.ResolveMax, 50.0, 300.0, 5.0, 100.0)
    ElseIf option == _oRegen
        OpenSlider(Manager.ResolveRegenPerSec, 0.0, 50.0, 1.0, 12.0)
    ElseIf option == _oBarrageCost
        OpenSlider(Manager.CostBarragePerSec, 0.0, 60.0, 1.0, 22.0)
    ElseIf option == _oBarrageDur
        OpenSlider(Manager.BarrageMaxDuration, 0.5, 10.0, 0.25, 3.0)
    ElseIf option == _oBarrageInt
        OpenSlider(Manager.BarrageTickInterval, 0.05, 0.4, 0.01, 0.12)
    ElseIf option == _oReachRange
        OpenSlider(Manager.ReachRange, 128.0, 2048.0, 32.0, 512.0)
    EndIf
EndEvent

Event OnOptionSliderAccept(Int option, Float value)
    If option == _oResolveMax
        Manager.ResolveMax = value
    ElseIf option == _oRegen
        Manager.ResolveRegenPerSec = value
    ElseIf option == _oBarrageCost
        Manager.CostBarragePerSec = value
    ElseIf option == _oBarrageDur
        Manager.BarrageMaxDuration = value
    ElseIf option == _oBarrageInt
        Manager.BarrageTickInterval = value
    ElseIf option == _oReachRange
        Manager.ReachRange = value
    EndIf
    SetSliderOptionValue(option, value, SliderFmt(option))
EndEvent

;======================================================================
; helpers
;======================================================================
Function OpenSlider(Float cur, Float lo, Float hi, Float step, Float def)
    SetSliderDialogStartValue(cur)
    SetSliderDialogDefaultValue(def)
    SetSliderDialogRange(lo, hi)
    SetSliderDialogInterval(step)
EndFunction

String Function SliderFmt(Int option)
    If option == _oBarrageDur || option == _oBarrageInt
        return "{2}"
    ElseIf option == _oRegen || option == _oBarrageCost
        return "{1}"
    EndIf
    return "{0}"
EndFunction

Float Function GetGlobal(GlobalVariable g)
    If g
        return g.GetValue()
    EndIf
    return 0.0
EndFunction

String Function BoolStr(Bool b)
    If b
        return "Yes"
    EndIf
    return "No"
EndFunction

String Function FloatStr(Float f)
    return (f as Int) as String
EndFunction
