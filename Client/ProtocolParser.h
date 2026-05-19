#pragma once

#include "Constants.h"
#include "DeviceStatus.h"

#include <optional>
#include <string>

class Headphones;

namespace ProtocolParser {
	std::optional<int> parseBatteryPercent(const Buffer& payload);
	std::optional<std::string> parseAudioCodec(const Buffer& payload);
	std::optional<std::string> parseFirmwareVersion(const Buffer& payload);
	bool applyAmbientSoundControl(Headphones& headphones, const Buffer& payload);
	bool applyAmbientSoundControlV2(Headphones& headphones, const Buffer& payload);
	bool applyVirtualSound(Headphones& headphones, const Buffer& payload);
	bool applyEqualizer(DeviceStatus& status, const Buffer& payload);
	bool applyTouchSensor(DeviceStatus& status, const Buffer& payload);
	bool applyVoiceGuidance(DeviceStatus& status, const Buffer& payload);
}
