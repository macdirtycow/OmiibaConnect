#include "ProtocolParser.h"
#include "Headphones.h"

#include <sstream>

namespace ProtocolParser {
	std::optional<int> parseBatteryPercent(const Buffer& payload) {
		if (payload.size() < 3) {
			return std::nullopt;
		}

		const auto batteryType = static_cast<unsigned char>(payload[1]);
		if (batteryType == 0x00 || batteryType == 0x02) {
			return static_cast<int>(static_cast<unsigned char>(payload[2]));
		}

		if (batteryType == 0x01 && payload.size() >= 3) {
			return static_cast<int>(static_cast<unsigned char>(payload[2]));
		}

		return std::nullopt;
	}

	std::optional<std::string> parseAudioCodec(const Buffer& payload) {
		if (payload.size() < 3 || payload[1] != 0x00) {
			return std::nullopt;
		}

		// com.sony.songpal.tandemfamily.message.mdr.v1.table1.param.AudioCodec (APK 9.5)
		switch (static_cast<unsigned char>(payload[2])) {
		case 0x00: return "Unsettled";
		case 0x01: return "SBC";
		case 0x02: return "AAC";
		case 0x10: return "LDAC";
		case 0x20: return "aptX";
		case 0x21: return "aptX HD";
		default: {
			std::ostringstream ss;
			ss << "Unknown (0x" << std::hex << static_cast<int>(static_cast<unsigned char>(payload[2])) << ")";
			return ss.str();
		}
		}
	}

	std::optional<std::string> parseFirmwareVersion(const Buffer& payload) {
		if (payload.size() < 4 || payload[1] != 0x02) {
			return std::nullopt;
		}

		const auto expectedLength = static_cast<unsigned char>(payload[2]);
		if (payload.size() < 3 + expectedLength) {
			return std::nullopt;
		}

		return std::string(payload.begin() + 3, payload.begin() + 3 + expectedLength);
	}

	bool applyAmbientSoundControl(Headphones& headphones, const Buffer& payload) {
		if (payload.size() != 8) {
			return false;
		}

		bool ambientEnabled = false;
		int asmLevel = 0;
		bool focusOnVoice = payload[6] == 0x01;

		if (payload[2] == 0x00) {
			ambientEnabled = false;
			asmLevel = 0;
		}
		else if (payload[3] == 0x00) {
			if (payload[4] == 0x00) {
				ambientEnabled = true;
				asmLevel = static_cast<unsigned char>(payload[7]);
			}
			else if (payload[4] == 0x01) {
				ambientEnabled = true;
				asmLevel = 0;
			}
			else {
				return false;
			}
		}
		else {
			return false;
		}

		headphones.applyDeviceState(ambientEnabled, focusOnVoice, asmLevel);
		return true;
	}

	bool applyAmbientSoundControlV2(Headphones& headphones, const Buffer& payload) {
		if (payload.size() < 7) {
			return false;
		}
		if (payload[1] != 0x15 && payload[1] != 0x17) {
			return false;
		}

		const bool includesWindNoise = payload[1] == 0x17 && payload.size() > 7;
		bool ambientEnabled = false;
		int asmLevel = 0;

		if (payload[3] == 0x01 && payload[4] == 0x01) {
			ambientEnabled = true;
		}

		const int focusIndex = includesWindNoise ? 6 : 5;
		const int levelIndex = focusIndex + 1;
		if (payload.size() <= static_cast<size_t>(levelIndex)) {
			return false;
		}

		const bool focusOnVoice = payload[focusIndex] == 0x01;
		if (ambientEnabled) {
			asmLevel = static_cast<unsigned char>(payload[levelIndex]);
		}

		headphones.applyDeviceState(ambientEnabled, focusOnVoice, asmLevel);
		return true;
	}

	bool applyVirtualSound(Headphones& headphones, const Buffer& payload) {
		if (payload.size() != 3) {
			return false;
		}

		if (payload[1] == 0x01) {
			headphones.applyDeviceVpt(static_cast<int>(static_cast<unsigned char>(payload[2])));
			headphones.applyDeviceSurroundPosition(SOUND_POSITION_PRESET::OFF);
			return true;
		}

		if (payload[1] == 0x02) {
			headphones.applyDeviceVpt(0);
			headphones.applyDeviceSurroundPosition(static_cast<SOUND_POSITION_PRESET>(payload[2]));
			return true;
		}

		return false;
	}

	bool applyEqualizer(DeviceStatus& status, const Buffer& payload) {
		if (payload.size() != 10) {
			return false;
		}

		status.eqPresetCode = static_cast<int>(static_cast<unsigned char>(payload[2]));
		status.eqBass = static_cast<int>(static_cast<unsigned char>(payload[4])) - 10;
		for (int i = 0; i < 5; i++) {
			status.eqBands[i] = static_cast<int>(static_cast<unsigned char>(payload[5 + i])) - 10;
		}
		status.hasEqualizer = true;
		return true;
	}

	bool applyTouchSensor(DeviceStatus& status, const Buffer& payload) {
		if (payload.size() != 4) {
			return false;
		}

		if (payload[3] == 0x00) {
			status.touchSensorEnabled = false;
		}
		else if (payload[3] == 0x01) {
			status.touchSensorEnabled = true;
		}
		else {
			return false;
		}

		status.hasTouchSensor = true;
		return true;
	}

	bool applyVoiceGuidance(DeviceStatus& status, const Buffer& payload) {
		if (payload.size() != 4) {
			return false;
		}

		if (payload[3] == 0x00) {
			status.voiceGuidanceEnabled = false;
		}
		else if (payload[3] == 0x01) {
			status.voiceGuidanceEnabled = true;
		}
		else {
			return false;
		}

		status.hasVoiceGuidance = true;
		return true;
	}
}
