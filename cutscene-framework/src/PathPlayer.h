#pragma once

#include <atomic>
#include <chrono>
#include <string>

#include "CameraPath.h"

// Drives the player camera along a CameraPath. Singleton.
//
// Per-frame stepping is done by re-arming an SKSE task each tick (no engine
// offset hooks), so this stays version-independent across SE/AE/1.6.1170/VR.
class PathPlayer
{
public:
	static PathPlayer& GetSingleton()
	{
		static PathPlayer s;
		return s;
	}

	// Papyrus-facing API ------------------------------------------------
	bool LoadPath(const std::string& a_path);   // load JSON, don't play
	bool LoadAndLaunch(const std::string& a_path);
	void Launch();                                // play the currently loaded path
	void Stop();

	bool  IsPlaying() const { return _playing.load(); }
	void  SetSpeed(float a_s) { _speed = (a_s > 0.0f) ? a_s : 0.0f; }
	void  Pause() { _paused = true; }
	void  Resume() { _paused = false; }
	float GetDuration() const { return _path.Duration(); }
	float GetTime() const { return _time; }
	void  SetLoop(bool a_b) { _path.SetLoop(a_b); }

	// Build a path from Papyrus, keyframe by keyframe -------------------
	void BeginPath();
	void AddKeyframe(float t, float x, float y, float z, float rxDeg, float ryDeg, float rzDeg, float fov);
	void LaunchBuiltPath();

	// Called every tick by the SKSE task.
	void Tick();

private:
	PathPlayer() = default;

	void Arm();
	void ApplyCameraState(bool a_takeControl);
	void ApplySample(const CameraPath::Sample& s);
	void Finish();

	CameraPath        _path;
	CameraPath        _builder;
	std::atomic<bool> _playing{ false };
	bool              _paused{ false };
	float             _time{ 0.0f };
	float             _speed{ 1.0f };
	bool              _haveSavedState{ false };

	std::chrono::steady_clock::time_point _lastTick;

	// Saved camera state to restore on Stop().
	RE::BSTSmartPointer<RE::TESCameraState> _prevState;
};

// Resolve a Papyrus path arg to a filesystem path (prepends the plugin folder
// if the arg has no directory component).
std::string ResolvePathArg(std::string a_arg);
