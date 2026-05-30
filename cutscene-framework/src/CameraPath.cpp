#include "CameraPath.h"

#include <algorithm>
#include <cmath>
#include <fstream>

#include <json/json.h>

namespace
{
	constexpr float kDeg2Rad = 0.01745329252f;

	float Lerp(float a, float b, float t) { return a + (b - a) * t; }

	RE::NiPoint3 LerpP(const RE::NiPoint3& a, const RE::NiPoint3& b, float t)
	{
		return RE::NiPoint3{ Lerp(a.x, b.x, t), Lerp(a.y, b.y, t), Lerp(a.z, b.z, t) };
	}

	// Catmull-Rom for one component (p1->p2 segment, p0/p3 neighbors).
	float CatmullRom(float p0, float p1, float p2, float p3, float t)
	{
		const float t2 = t * t;
		const float t3 = t2 * t;
		return 0.5f * ((2.0f * p1) + (-p0 + p2) * t + (2.0f * p0 - 5.0f * p1 + 4.0f * p2 - p3) * t2 +
						  (-p0 + 3.0f * p1 - 3.0f * p2 + p3) * t3);
	}

	RE::NiPoint3 CatmullRomP(const RE::NiPoint3& p0, const RE::NiPoint3& p1, const RE::NiPoint3& p2,
		const RE::NiPoint3& p3, float t)
	{
		return RE::NiPoint3{ CatmullRom(p0.x, p1.x, p2.x, p3.x, t), CatmullRom(p0.y, p1.y, p2.y, p3.y, t),
			CatmullRom(p0.z, p1.z, p2.z, p3.z, t) };
	}
}

void CameraPath::AddKeyframe(const Keyframe& k)
{
	_keys.push_back(k);
}

void CameraPath::Finalize()
{
	std::stable_sort(_keys.begin(), _keys.end(),
		[](const Keyframe& a, const Keyframe& b) { return a.time < b.time; });
}

float CameraPath::Duration() const
{
	return _keys.empty() ? 0.0f : _keys.back().time;
}

CameraPath::Sample CameraPath::SampleAt(float t) const
{
	if (_keys.empty()) {
		return Sample{ RE::NiPoint3{}, RE::NiPoint3{}, 0.0f };
	}
	if (_keys.size() == 1 || t <= _keys.front().time) {
		const auto& k = _keys.front();
		return Sample{ k.pos, k.euler, k.fov };
	}
	if (t >= _keys.back().time) {
		const auto& k = _keys.back();
		return Sample{ k.pos, k.euler, k.fov };
	}

	// Find segment [i, i+1] containing t.
	std::size_t i = 0;
	while (i + 1 < _keys.size() && _keys[i + 1].time < t) {
		++i;
	}
	const auto& a = _keys[i];
	const auto& b = _keys[i + 1];
	const float span = b.time - a.time;
	const float local = span > 0.0001f ? (t - a.time) / span : 0.0f;

	// Neighbors for Catmull-Rom (clamped at ends).
	const auto& p0 = _keys[i == 0 ? 0 : i - 1];
	const auto& p3 = _keys[i + 2 < _keys.size() ? i + 2 : i + 1];

	Sample s;
	s.pos = CatmullRomP(p0.pos, a.pos, b.pos, p3.pos, local);
	s.euler = LerpP(a.euler, b.euler, local);
	s.fov = (a.fov > 0.0f && b.fov > 0.0f) ? Lerp(a.fov, b.fov, local) : a.fov;
	return s;
}

bool CameraPath::LoadFromFile(const std::string& a_path)
{
	std::ifstream file(a_path);
	if (!file.is_open()) {
		logger::error("CameraPath: cannot open '{}'", a_path);
		return false;
	}

	Json::Value  root;
	Json::CharReaderBuilder builder;
	std::string  errs;
	if (!Json::parseFromStream(builder, file, &root, &errs)) {
		logger::error("CameraPath: JSON parse error in '{}': {}", a_path, errs);
		return false;
	}

	Clear();
	_loop = root.get("loop", false).asBool();

	const Json::Value& frames = root["keyframes"];
	if (!frames.isArray() || frames.empty()) {
		logger::error("CameraPath: '{}' has no keyframes", a_path);
		return false;
	}

	for (const auto& jf : frames) {
		Keyframe k;
		k.time = jf.get("time", 0.0f).asFloat();
		const auto& jp = jf["pos"];
		if (jp.isArray() && jp.size() == 3) {
			k.pos = RE::NiPoint3{ jp[0].asFloat(), jp[1].asFloat(), jp[2].asFloat() };
		}
		const auto& jr = jf["rot"];
		if (jr.isArray() && jr.size() == 3) {
			k.euler = RE::NiPoint3{ jr[0].asFloat() * kDeg2Rad, jr[1].asFloat() * kDeg2Rad,
				jr[2].asFloat() * kDeg2Rad };
		}
		k.fov = jf.get("fov", 0.0f).asFloat();
		AddKeyframe(k);
	}

	Finalize();
	logger::info("CameraPath: loaded {} keyframes ({}s) from '{}'", frames.size(), Duration(), a_path);
	return true;
}
