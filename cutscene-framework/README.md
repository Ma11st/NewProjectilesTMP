# CinematicCamera v2 — cutscene framework (CommonLibSSE-NG)

A modernized rebuild of the CinematicCamera SKSE plugin, plus a plug-n-play Papyrus
cutscene layer. The original DLL was built against an older CommonLibSSE and is **not
compatible with Skyrim AE 1.6.1170**. This rebuild targets **CommonLibSSE-NG** with the
**versionless Address Library**, so a *single* DLL runs on **SE (1.5.97), AE (all, incl.
1.6.1170), and VR**.

> **Why this fixes 1170:** the incompatibility lives in the native DLL (hard-coded
> address-library offsets for an old runtime), not in the Papyrus stub. NG's
> `USE_ADDRESS_LIBRARY` build resolves engine addresses at load time per runtime, so the
> same binary works everywhere Address Library has data — including 1.6.1170.

## What this is (and isn't)

Because the uploaded zip contained only the compiled DLL (no C++ source), the playback
engine here is a **faithful reconstruction**, not a recompile of the original:

| Area | Status |
|------|--------|
| The 3 original natives (`LoadAndLaunch` / `Launch` / `Stop`) | ✅ same names/behavior — old scripts keep working |
| New playback + path-building + sequencing API | ✅ added (see below) |
| Path format | 🔁 **new JSON format** (the original's binary `DemoPath` is not reused) |
| In-game path **editor** (the original's hotkey editor) | ❌ not reconstructed — paths are authored as JSON or built from Papyrus instead |

## New Papyrus API (`CinematicCamera`)

```
; --- legacy (unchanged) ---
bool  LoadAndLaunch(string path)
      Launch()
      Stop()
; --- new: control ---
bool  LoadPath(string path)      ; load without playing
bool  IsPlaying()
      SetSpeed(float speed)      ; 0.5 slow-mo, 2.0 fast
      Pause() / Resume()
float GetDuration() / GetTime()
      SetLoop(bool enable)
; --- new: build a path live, no file needed ---
      BeginPath()
      AddKeyframe(float time, float x,y,z, float pitch,roll,yaw, float fov)
      LaunchBuiltPath()
```

Plus a **completion mod event** so cutscenes can chain:
`RegisterForModEvent("CinematicCamera_OnFinish", "OnCCFinish")`.

## Plug-n-play layer (`CutsceneDirector`)

Attach `CutsceneDirector` to a quest and run a full cutscene — fade, freeze player, hide
HUD, auto-restore on finish — in one call:

```papyrus
Director.PlayCutscene("MyScene.json")          ; from a JSON path
Director.PlayMarkers(myMarkers, 3.0, 60.0)     ; built from CK markers (pos + angles)
Director.PlayBuiltCutscene()                   ; after CinematicCamera.BeginPath/AddKeyframe
Director.StopCutscene()                         ; bail early
```

It restores controls/HUD automatically when the path ends (via the `OnFinish` event) or on
a mid-cutscene save load. Optional `ImageSpaceModifier` properties give you fades + letterbox.

## Path JSON format

`Data/SKSE/Plugins/CinematicCamera/<name>.json` (see `paths/example_pan.json`):

```json
{
  "loop": false,
  "keyframes": [
    { "time": 0.0, "pos": [x, y, z], "rot": [pitch, roll, yaw], "fov": 80.0 }
  ]
}
```
- `time` seconds, `pos` world units, `rot` **degrees**, `fov` `<= 0` = leave FOV alone.
- Position is **Catmull-Rom** interpolated (smooth); rotation/FOV are linear.

## Building (you compile — I can't here)

```
# one-time: install vcpkg, set VCPKG_ROOT
cmake --preset release
cmake --build build --config Release
```
- `vcpkg.json` + `vcpkg-configuration.json` pull **commonlibsse-ng** (colorglass registry)
  and jsoncpp. `CMakeLists.txt` uses `add_commonlibsse_plugin(... USE_ADDRESS_LIBRARY)`.
- Output `CinematicCamera.dll` → `Data/SKSE/Plugins/`. Compile the two `.psc` with the
  CK/Caprica. Ship Address Library + SKSE as deps.

## ⚠️ Honest caveat — verify the camera-apply

I can't compile or run Skyrim/C++ in this environment, so the plugin is written but
**unbuilt**. The path math, JSON, task loop, Papyrus bindings, mod event, and the whole
Papyrus layer are straightforward and should be correct. The one place to **verify against
your CommonLibSSE-NG headers** is the ~20-line *engine integration point* in
`src/PathPlayer.cpp` (`ApplyCameraState` / `ApplySample`) — specifically the
`RE::FreeCameraState` field names and the euler→matrix convention. If the camera ends up
mispositioned or rotated on an axis, that function is where to adjust. Everything else is
framework you shouldn't need to touch.

## Files
```
cutscene-framework/
  CMakeLists.txt  CMakePresets.json  vcpkg.json  vcpkg-configuration.json
  src/  PCH.h  CameraPath.{h,cpp}  PathPlayer.{h,cpp}  Papyrus.{h,cpp}  plugin.cpp
  scripts/source/  CinematicCamera.psc  CutsceneDirector.psc
  paths/  example_pan.json
```
