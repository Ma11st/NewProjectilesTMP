#include "PathPlayer.h"

#include <cmath>

namespace
{
	// Build a rotation matrix from euler angles (radians), XYZ order.
	// NOTE: Skyrim's camera rotation convention is finicky; if the camera looks
	// "off" by an axis, this is the one place to adjust (swap/negate an axis).
	RE::NiMatrix3 EulerToMatrix(const RE::NiPoint3& e)
	{
		const float cx = std::cos(e.x), sx = std::sin(e.x);
		const float cy = std::cos(e.y), sy = std::sin(e.y);
		const float cz = std::cos(e.z), sz = std::sin(e.z);

		RE::NiMatrix3 m;
		m.entry[0][0] = cy * cz;
		m.entry[0][1] = -cy * sz;
		m.entry[0][2] = sy;
		m.entry[1][0] = sx * sy * cz + cx * sz;
		m.entry[1][1] = -sx * sy * sz + cx * cz;
		m.entry[1][2] = -sx * cy;
		m.entry[2][0] = -cx * sy * cz + sx * sz;
		m.entry[2][1] = cx * sy * sz + sx * cz;
		m.entry[2][2] = cx * cy;
		return m;
	}

	void SetWorldFOV(float fov)
	{
		if (fov <= 0.0f) {
			return;
		}
		if (auto* col = RE::INISettingCollection::GetSingleton()) {
			if (auto* s = col->GetSetting("fDefaultWorldFOV:Display")) {
				s->data.f = fov;
			}
		}
		if (auto* col = RE::INIPrefSettingCollection::GetSingleton()) {
			if (auto* s = col->GetSetting("fDefaultWorldFOV:Display")) {
				s->data.f = fov;
			}
		}
	}

	void SendFinishEvent()
	{
		if (auto* src = SKSE::GetModCallbackEventSource()) {
			SKSE::ModCallbackEvent ev{};
			ev.eventName = RE::BSFixedString("CinematicCamera_OnFinish");
			ev.strArg = RE::BSFixedString("");
			ev.numArg = 0.0f;
			ev.sender = nullptr;
			src->SendEvent(&ev);
		}
	}
}

std::string ResolvePathArg(std::string a_arg)
{
	if (a_arg.find('/') != std::string::npos || a_arg.find('\\') != std::string::npos ||
		a_arg.find(':') != std::string::npos) {
		return a_arg;
	}
	return "Data/SKSE/Plugins/CinematicCamera/" + a_arg;
}

bool PathPlayer::LoadPath(const std::string& a_path)
{
	return _path.LoadFromFile(ResolvePathArg(a_path));
}

bool PathPlayer::LoadAndLaunch(const std::string& a_path)
{
	if (!LoadPath(a_path)) {
		return false;
	}
	Launch();
	return true;
}

void PathPlayer::Launch()
{
	if (_path.Empty()) {
		logger::warn("PathPlayer::Launch with empty path");
		return;
	}
	if (_playing.load()) {
		Stop();
	}
	_time = 0.0f;
	_paused = false;
	_lastTick = std::chrono::steady_clock::now();
	ApplyCameraState(true);
	_playing.store(true);
	Arm();
}

void PathPlayer::Stop()
{
	if (!_playing.load()) {
		return;
	}
	_playing.store(false);
	ApplyCameraState(false);
}

void PathPlayer::BeginPath()
{
	_builder.Clear();
}

void PathPlayer::AddKeyframe(float t, float x, float y, float z, float rxDeg, float ryDeg, float rzDeg, float fov)
{
	constexpr float kDeg2Rad = 0.01745329252f;
	CameraPath::Keyframe k;
	k.time = t;
	k.pos = RE::NiPoint3{ x, y, z };
	k.euler = RE::NiPoint3{ rxDeg * kDeg2Rad, ryDeg * kDeg2Rad, rzDeg * kDeg2Rad };
	k.fov = fov;
	_builder.AddKeyframe(k);
}

void PathPlayer::LaunchBuiltPath()
{
	_builder.Finalize();
	if (_builder.Empty()) {
		logger::warn("PathPlayer::LaunchBuiltPath with no keyframes");
		return;
	}
	_path = _builder;
	Launch();
}

void PathPlayer::Tick()
{
	if (!_playing.load()) {
		return;
	}

	const auto now = std::chrono::steady_clock::now();
	const float dt = std::chrono::duration<float>(now - _lastTick).count();
	_lastTick = now;

	if (!_paused) {
		_time += dt * _speed;
	}

	const float dur = _path.Duration();
	if (_time >= dur) {
		if (_path.Loop()) {
			_time = (dur > 0.0001f) ? std::fmod(_time, dur) : 0.0f;
		} else {
			ApplySample(_path.SampleAt(dur));
			Finish();
			return;
		}
	}

	ApplySample(_path.SampleAt(_time));
	Arm();
}

void PathPlayer::Finish()
{
	_playing.store(false);
	ApplyCameraState(false);
	SendFinishEvent();
}

void PathPlayer::Arm()
{
	if (auto* task = SKSE::GetTaskInterface()) {
		task->AddTask([]() { PathPlayer::GetSingleton().Tick(); });
	}
}

// === ENGINE INTEGRATION POINT ========================================
// Switch the player camera into a controllable free state on take-control,
// and restore the prior state on release. Verify the FreeCameraState field
// names against your RE/FreeCameraState.h if the camera misbehaves.
void PathPlayer::ApplyCameraState(bool a_takeControl)
{
	auto* pc = RE::PlayerCamera::GetSingleton();
	if (!pc) {
		return;
	}

	if (a_takeControl) {
		if (!_haveSavedState) {
			_prevState = pc->currentState;
			_haveSavedState = true;
		}
		// Enter free-fly so we own the transform each frame.
		if (auto& freeState = pc->cameraStates[RE::CameraState::kFree]) {
			pc->SetState(freeState.get());
		}
	} else {
		if (_haveSavedState && _prevState) {
			pc->SetState(_prevState.get());
		} else {
			// Fallback: drop back to third person.
			if (auto& tp = pc->cameraStates[RE::CameraState::kThirdPerson]) {
				pc->SetState(tp.get());
			}
		}
		_prevState.reset();
		_haveSavedState = false;
	}
}

void PathPlayer::ApplySample(const CameraPath::Sample& s)
{
	auto* pc = RE::PlayerCamera::GetSingleton();
	if (!pc) {
		return;
	}

	const RE::NiMatrix3 rot = EulerToMatrix(s.euler);

	// Free-camera state stores the absolute camera translation.
	if (auto* free = skyrim_cast<RE::FreeCameraState*>(pc->currentState.get())) {
		free->translation = s.pos;
	}

	// Drive the camera root node transform directly (position + orientation).
	if (auto* root = pc->cameraRoot.get()) {
		root->world.translate = s.pos;
		root->world.rotate = rot;
		root->local.translate = s.pos;
		root->local.rotate = rot;
	}

	SetWorldFOV(s.fov);
}
