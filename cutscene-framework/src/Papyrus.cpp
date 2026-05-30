#include "Papyrus.h"

#include <string>

#include "PathPlayer.h"

namespace
{
	constexpr const char* kClass = "CinematicCamera";

	// --- legacy API (kept identical so old scripts keep working) ---------
	bool LoadAndLaunch(RE::StaticFunctionTag*, RE::BSFixedString a_path)
	{
		return PathPlayer::GetSingleton().LoadAndLaunch(std::string(a_path.c_str()));
	}
	void Launch(RE::StaticFunctionTag*) { PathPlayer::GetSingleton().Launch(); }
	void Stop(RE::StaticFunctionTag*) { PathPlayer::GetSingleton().Stop(); }

	// --- new API ---------------------------------------------------------
	bool LoadPath(RE::StaticFunctionTag*, RE::BSFixedString a_path)
	{
		return PathPlayer::GetSingleton().LoadPath(std::string(a_path.c_str()));
	}
	bool IsPlaying(RE::StaticFunctionTag*) { return PathPlayer::GetSingleton().IsPlaying(); }
	void SetSpeed(RE::StaticFunctionTag*, float a_s) { PathPlayer::GetSingleton().SetSpeed(a_s); }
	void Pause(RE::StaticFunctionTag*) { PathPlayer::GetSingleton().Pause(); }
	void Resume(RE::StaticFunctionTag*) { PathPlayer::GetSingleton().Resume(); }
	float GetDuration(RE::StaticFunctionTag*) { return PathPlayer::GetSingleton().GetDuration(); }
	float GetTime(RE::StaticFunctionTag*) { return PathPlayer::GetSingleton().GetTime(); }
	void SetLoop(RE::StaticFunctionTag*, bool a_b) { PathPlayer::GetSingleton().SetLoop(a_b); }

	// Build a path from Papyrus, then play it.
	void BeginPath(RE::StaticFunctionTag*) { PathPlayer::GetSingleton().BeginPath(); }
	void AddKeyframe(RE::StaticFunctionTag*, float a_time, float a_x, float a_y, float a_z, float a_rx,
		float a_ry, float a_rz, float a_fov)
	{
		PathPlayer::GetSingleton().AddKeyframe(a_time, a_x, a_y, a_z, a_rx, a_ry, a_rz, a_fov);
	}
	void LaunchBuiltPath(RE::StaticFunctionTag*) { PathPlayer::GetSingleton().LaunchBuiltPath(); }
}

bool Papyrus::Register(RE::BSScript::IVirtualMachine* a_vm)
{
	a_vm->RegisterFunction("LoadAndLaunch", kClass, LoadAndLaunch);
	a_vm->RegisterFunction("Launch", kClass, Launch);
	a_vm->RegisterFunction("Stop", kClass, Stop);

	a_vm->RegisterFunction("LoadPath", kClass, LoadPath);
	a_vm->RegisterFunction("IsPlaying", kClass, IsPlaying);
	a_vm->RegisterFunction("SetSpeed", kClass, SetSpeed);
	a_vm->RegisterFunction("Pause", kClass, Pause);
	a_vm->RegisterFunction("Resume", kClass, Resume);
	a_vm->RegisterFunction("GetDuration", kClass, GetDuration);
	a_vm->RegisterFunction("GetTime", kClass, GetTime);
	a_vm->RegisterFunction("SetLoop", kClass, SetLoop);

	a_vm->RegisterFunction("BeginPath", kClass, BeginPath);
	a_vm->RegisterFunction("AddKeyframe", kClass, AddKeyframe);
	a_vm->RegisterFunction("LaunchBuiltPath", kClass, LaunchBuiltPath);

	logger::info("CinematicCamera: registered Papyrus natives");
	return true;
}
