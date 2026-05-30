#include "Papyrus.h"
#include "PathPlayer.h"

namespace
{
	void SetupLog()
	{
		auto path = logger::log_directory();
		if (!path) {
			return;
		}
		*path /= "CinematicCamera.log";
		auto sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(path->string(), true);
		auto log = std::make_shared<spdlog::logger>("global", std::move(sink));
		log->set_level(spdlog::level::info);
		log->flush_on(spdlog::level::info);
		spdlog::set_default_logger(std::move(log));
		spdlog::set_pattern("[%H:%M:%S] [%l] %v");
	}

	void OnMessage(SKSE::MessagingInterface::Message* a_msg)
	{
		// If a save is loaded mid-cutscene, make sure we relinquish the camera.
		if (a_msg->type == SKSE::MessagingInterface::kPreLoadGame) {
			PathPlayer::GetSingleton().Stop();
		}
	}
}

SKSEPluginLoad(const SKSE::LoadInterface* a_skse)
{
	SetupLog();
	SKSE::Init(a_skse);

	logger::info("CinematicCamera v2 loading (CommonLibSSE-NG, SE/AE/1.6.1170/VR)");

	if (!SKSE::GetPapyrusInterface()->Register(Papyrus::Register)) {
		logger::critical("Failed to register Papyrus interface");
		return false;
	}

	if (auto* msg = SKSE::GetMessagingInterface()) {
		msg->RegisterListener(OnMessage);
	}

	return true;
}
