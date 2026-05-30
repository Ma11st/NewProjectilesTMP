Scriptname CinematicCamera

{ Native API for the CinematicCamera SKSE plugin (CommonLibSSE-NG; SE/AE/1.6.1170/VR).
  The first three functions are unchanged from the original mod, so existing
  scripts keep working. Everything below them is new. }

;==================== Legacy (unchanged) ============================

{Load a camera path (JSON) and start playing it. Returns false if loading failed.
 If the path has no directory, it is read from Data/SKSE/Plugins/CinematicCamera/.}
bool function LoadAndLaunch(string path) global native

{Start playing the currently loaded path (load once with LoadPath/LoadAndLaunch first).}
function Launch() global native

{Stop playback and hand the camera back to the game.}
function Stop() global native

;==================== New: playback control =========================

{Load a path (JSON) without playing it. Returns false on error.}
bool function LoadPath(string path) global native

{Is a cutscene currently playing?}
bool function IsPlaying() global native

{Playback speed multiplier (1.0 = normal, 0.5 = slow-mo, 2.0 = fast).}
function SetSpeed(float speed) global native

{Pause playback (camera holds its current frame).}
function Pause() global native

{Resume after Pause.}
function Resume() global native

{Total length of the loaded path, in seconds.}
float function GetDuration() global native

{Current playback time, in seconds.}
float function GetTime() global native

{Loop the path instead of ending (and firing OnFinish).}
function SetLoop(bool enable) global native

;==================== New: build a path from Papyrus ================
; Build a path in memory, then play it -- no JSON file needed.
;   CinematicCamera.BeginPath()
;   CinematicCamera.AddKeyframe(0.0, x,y,z, pitch,roll,yaw, 75.0)
;   CinematicCamera.AddKeyframe(3.0, ...)
;   CinematicCamera.LaunchBuiltPath()

{Start a new in-memory path (clears any previously built one).}
function BeginPath() global native

{Append a keyframe. Angles are DEGREES. fov <= 0 leaves FOV untouched.}
function AddKeyframe(float time, float x, float y, float z, float pitch, float roll, float yaw, float fov) global native

{Play the path built with BeginPath/AddKeyframe.}
function LaunchBuiltPath() global native

;==================== Completion event ==============================
; The plugin sends a mod event "CinematicCamera_OnFinish" when a non-looping
; path ends. Listen for it to chain cutscenes:
;   RegisterForModEvent("CinematicCamera_OnFinish", "OnCCFinish")
;   Event OnCCFinish(string en, string sa, float na, Form sender) ... EndEvent
