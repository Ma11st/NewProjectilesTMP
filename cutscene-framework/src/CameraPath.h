#pragma once

#include <optional>
#include <string>
#include <vector>

// A camera path: a time-ordered list of keyframes. Position is Catmull-Rom
// interpolated for smoothness; rotation (euler, radians) and FOV are linear.
class CameraPath
{
public:
	struct Keyframe
	{
		float           time = 0.0f;          // seconds from path start
		RE::NiPoint3    pos{ 0.0f, 0.0f, 0.0f };
		RE::NiPoint3    euler{ 0.0f, 0.0f, 0.0f };  // radians (x=pitch, y=roll, z=yaw)
		float           fov = 0.0f;            // <= 0 means "leave FOV untouched"
	};

	struct Sample
	{
		RE::NiPoint3 pos;
		RE::NiPoint3 euler;
		float        fov;
	};

	void  Clear() { _keys.clear(); }
	bool  Empty() const { return _keys.empty(); }
	void  AddKeyframe(const Keyframe& k);
	void  Finalize();                           // sort by time
	float Duration() const;
	bool  Loop() const { return _loop; }
	void  SetLoop(bool b) { _loop = b; }

	// Interpolated transform at time t (seconds). Clamped to [0, Duration].
	Sample SampleAt(float t) const;

	// Load from a JSON file (see paths/example_pan.json). Angles in the file are
	// DEGREES (human-friendly); converted to radians here. Returns false on error.
	bool LoadFromFile(const std::string& a_path);

private:
	std::vector<Keyframe> _keys;
	bool                  _loop = false;
};
