#include "Headphones.h"
#include "CommandSerializer.h"
#include "ProtocolParser.h"

#include <algorithm>
#include <optional>
#include <stdexcept>

Headphones::Headphones(BluetoothWrapper& conn) : _conn(conn)
{
}

void Headphones::setAmbientSoundControl(bool val)
{
	std::lock_guard guard(this->_propertyMtx);
	this->_ambientSoundControl.desired = val;
}

bool Headphones::getAmbientSoundControl()
{
	return this->_ambientSoundControl.current;
}

bool Headphones::isFocusOnVoiceAvailable()
{
	return this->_ambientSoundControl.current && this->_asmLevel.current > MINIMUM_VOICE_FOCUS_STEP;
}

void Headphones::setFocusOnVoice(bool val)
{
	std::lock_guard guard(this->_propertyMtx);
	this->_focusOnVoice.desired = val;
}

bool Headphones::getFocusOnVoice()
{
	return this->_focusOnVoice.current;
}

bool Headphones::isSetAsmLevelAvailable()
{
	return this->_ambientSoundControl.current;
}

void Headphones::setAsmLevel(int val)
{
	std::lock_guard guard(this->_propertyMtx);
	this->_asmLevel.desired = val;
}

int Headphones::getAsmLevel()
{
	return this->_asmLevel.current;
}

int Headphones::getDisplayAsmLevel() const
{
	std::lock_guard guard(this->_propertyMtx);
	return this->_asmLevel.isFulfilled() ? this->_asmLevel.current : this->_asmLevel.desired;
}

bool Headphones::hasPendingAmbientChanges() const
{
	std::lock_guard guard(this->_propertyMtx);
	return !this->_ambientSoundControl.isFulfilled()
		|| !this->_asmLevel.isFulfilled()
		|| !this->_focusOnVoice.isFulfilled();
}

void Headphones::setSurroundPosition(SOUND_POSITION_PRESET val)
{
	std::lock_guard guard(this->_propertyMtx);
	this->_surroundPosition.desired = val;
}

SOUND_POSITION_PRESET Headphones::getSurroundPosition()
{
	return this->_surroundPosition.current;
}

void Headphones::setVptType(int val)
{
	std::lock_guard guard(this->_propertyMtx);
	this->_vptType.desired = val;
}

int Headphones::getVptType()
{
	return this->_vptType.current;
}

void Headphones::setEqualizerPreset(EQ_PRESET preset)
{
	std::lock_guard guard(this->_propertyMtx);
	this->_eqPreset.desired = preset;
}

EQ_PRESET Headphones::getEqualizerPreset() const
{
	return this->_eqPreset.current;
}

EQ_PRESET Headphones::getDisplayEqPreset() const
{
	std::lock_guard guard(this->_propertyMtx);
	return this->_eqPreset.isFulfilled() ? this->_eqPreset.current : this->_eqPreset.desired;
}

bool Headphones::hasPendingEqChanges() const
{
	std::lock_guard guard(this->_propertyMtx);
	return !this->_eqPreset.isFulfilled();
}

void Headphones::setTouchSensorEnabled(bool enabled)
{
	std::lock_guard guard(this->_propertyMtx);
	this->_touchSensorEnabled.desired = enabled;
}

bool Headphones::getTouchSensorEnabled() const
{
	return this->_touchSensorEnabled.current;
}

void Headphones::setVoiceGuidanceEnabled(bool enabled)
{
	std::lock_guard guard(this->_propertyMtx);
	this->_voiceGuidanceEnabled.desired = enabled;
}

bool Headphones::getVoiceGuidanceEnabled() const
{
	return this->_voiceGuidanceEnabled.current;
}

const DeviceStatus& Headphones::getDeviceStatus() const
{
	return this->_deviceStatus;
}

const DeviceCapabilities& Headphones::getCapabilities() const
{
	return this->_capabilities;
}

void Headphones::configureForDevice(std::string_view deviceName)
{
	this->_deviceName.assign(deviceName);
	this->_capabilities = buildDeviceProfile(this->_deviceName, std::nullopt);
	this->_deviceStatus.modelName = this->_capabilities.model == SonyHeadphoneModel::Unknown
		? this->_deviceName
		: modelDisplayName(this->_capabilities.model);
	this->_deviceStatus.protocolLabel = this->_capabilities.usesV2AmbientSound ? "MDR v2" : "MDR v1";

	if (!this->_capabilities.supportsTouchSensor) {
		this->_touchSensorEnabled.fulfill();
	}
	if (!this->_capabilities.supportsEqualizer) {
		this->_eqPreset.fulfill();
	}
	if (!this->_capabilities.supportsVoiceGuidance) {
		this->_voiceGuidanceEnabled.fulfill();
	}
	if (!this->_capabilities.supportsVirtualSound) {
		this->_vptType.fulfill();
		this->_surroundPosition.fulfill();
	}
}

void Headphones::applyDeviceState(bool ambientEnabled, bool focusOnVoice, int asmLevel)
{
	std::lock_guard guard(this->_propertyMtx);
	this->_ambientSoundControl.current = ambientEnabled;
	this->_ambientSoundControl.desired = ambientEnabled;
	this->_focusOnVoice.current = focusOnVoice;
	this->_focusOnVoice.desired = focusOnVoice;
	this->_asmLevel.current = asmLevel;
	this->_asmLevel.desired = asmLevel;
}

void Headphones::applyDeviceVpt(int vptType)
{
	std::lock_guard guard(this->_propertyMtx);
	this->_vptType.current = vptType;
	this->_vptType.desired = vptType;
}

void Headphones::applyDeviceSurroundPosition(SOUND_POSITION_PRESET preset)
{
	std::lock_guard guard(this->_propertyMtx);
	this->_surroundPosition.current = preset;
	this->_surroundPosition.desired = preset;
}

bool Headphones::performConnectHandshake()
{
	if (this->_handshakeComplete) {
		return true;
	}

	// Sony | Sound Connect always sends CONNECT_GET_PROTOCOL_INFO first; without it
	// many GET commands return nothing (mdr-protocol / APK: tandemfamily.message.mdr).
	// Gadgetbridge init: { 0x00, 0x00 } — required before other queries respond.
	const Buffer protocolInfo = {
		static_cast<char>(PAYLOAD_CMD::CONNECT_GET_PROTOCOL_INFO),
		0x00
	};
	std::optional<size_t> initPayloadLength;
	if (auto payload = this->_conn.sendQuery(
		protocolInfo,
		DATA_TYPE::DATA_MDR,
		static_cast<unsigned char>(PAYLOAD_CMD::CONNECT_RET_PROTOCOL_INFO))) {
		initPayloadLength = payload->size();
	}

	// APK 9.5: CONNECT_GET_CAPABILITY_INFO + CommonCapabilityInquiredType::FIXED_VALUE (0x00).
	const Buffer capabilityInfo = {
		static_cast<char>(PAYLOAD_CMD::CONNECT_GET_CAPABILITY_INFO),
		0x00
	};
	this->_conn.sendQuery(
		capabilityInfo,
		DATA_TYPE::DATA_MDR,
		static_cast<unsigned char>(PAYLOAD_CMD::CONNECT_RET_CAPABILITY_INFO));

	this->_capabilities = buildDeviceProfile(this->_deviceName, initPayloadLength);
	this->_deviceStatus.modelName = this->_capabilities.model == SonyHeadphoneModel::Unknown
		? this->_deviceName
		: modelDisplayName(this->_capabilities.model);
	this->_deviceStatus.protocolLabel = this->_capabilities.usesV2AmbientSound ? "MDR v2" : "MDR v1";

	const Buffer supportFn = { static_cast<char>(PAYLOAD_CMD::CONNECT_GET_SUPPORT_FUNCTION) };
	this->_conn.sendQuery(
		supportFn,
		DATA_TYPE::DATA_MDR,
		static_cast<unsigned char>(PAYLOAD_CMD::CONNECT_RET_SUPPORT_FUNCTION)
	);

	this->_handshakeComplete = true;
	return true;
}

bool Headphones::refreshFromDevice(bool includeExtendedSettings)
{
	if (!this->_conn.isConnected()) {
		return false;
	}

	performConnectHandshake();

	DeviceStatus nextStatus = this->_deviceStatus;

	if (this->_capabilities.usesV2AmbientSound) {
		const unsigned char variant = this->_capabilities.supportsWindNoiseMode ? 0x17 : 0x15;
		const Buffer ncQuery = {
			static_cast<char>(PAYLOAD_CMD::NCASM_GET),
			static_cast<char>(variant)
		};
		if (auto payload = this->_conn.sendQuery(ncQuery, DATA_TYPE::DATA_MDR, static_cast<unsigned char>(PAYLOAD_CMD::NCASM_RET))) {
			if (!ProtocolParser::applyAmbientSoundControlV2(*this, *payload)) {
				ProtocolParser::applyAmbientSoundControl(*this, *payload);
			}
		}
	} else {
		const Buffer ncQuery = {
			static_cast<char>(COMMAND_TYPE::NCASM_GET_PARAM),
			static_cast<char>(NC_ASM_INQUIRED_TYPE::NOISE_CANCELLING_AND_AMBIENT_SOUND_MODE)
		};
		if (auto payload = this->_conn.sendQuery(ncQuery, DATA_TYPE::DATA_MDR, static_cast<unsigned char>(PAYLOAD_CMD::NCASM_RET))) {
			ProtocolParser::applyAmbientSoundControl(*this, *payload);
		}
	}

	const Buffer batteryQuery = {
		static_cast<char>(PAYLOAD_CMD::BATTERY_REQUEST),
		0x00
	};
	if (auto payload = this->_conn.sendQuery(
		batteryQuery,
		DATA_TYPE::DATA_MDR,
		{
			static_cast<unsigned char>(PAYLOAD_CMD::BATTERY_RET),
			static_cast<unsigned char>(PAYLOAD_CMD::BATTERY_NTFY)
		})) {
		if (auto level = ProtocolParser::parseBatteryPercent(*payload)) {
			nextStatus.batteryPercent = *level;
			nextStatus.hasBattery = true;
		}
	}

	const Buffer codecQuery = {
		static_cast<char>(PAYLOAD_CMD::AUDIO_CODEC_REQUEST),
		0x00
	};
	if (auto payload = this->_conn.sendQuery(
		codecQuery,
		DATA_TYPE::DATA_MDR,
		{
			static_cast<unsigned char>(PAYLOAD_CMD::AUDIO_CODEC_RET),
			static_cast<unsigned char>(PAYLOAD_CMD::AUDIO_CODEC_NTFY)
		})) {
		if (auto codec = ProtocolParser::parseAudioCodec(*payload)) {
			nextStatus.audioCodec = *codec;
			nextStatus.hasCodec = true;
		}
	}

	const Buffer fwQuery = {
		static_cast<char>(PAYLOAD_CMD::CONNECT_GET_DEVICE_INFO),
		static_cast<char>(DEVICE_INFO_TYPE::FW_VERSION)
	};
	if (auto payload = this->_conn.sendQuery(fwQuery, DATA_TYPE::DATA_MDR, static_cast<unsigned char>(PAYLOAD_CMD::FW_VERSION_RET))) {
		if (auto fw = ProtocolParser::parseFirmwareVersion(*payload)) {
			nextStatus.firmwareVersion = *fw;
			nextStatus.hasFirmware = true;
		}
	}

	if (!includeExtendedSettings) {
		nextStatus.modelName = this->_deviceStatus.modelName;
		nextStatus.protocolLabel = this->_deviceStatus.protocolLabel;
		this->_deviceStatus = nextStatus;
		return nextStatus.hasBattery || nextStatus.hasCodec || nextStatus.hasFirmware;
	}

	if (this->_capabilities.supportsEqualizer) {
		const Buffer eqQuery = {
			static_cast<char>(PAYLOAD_CMD::EQ_GET),
			0x01
		};
		if (auto payload = this->_conn.sendQuery(eqQuery, DATA_TYPE::DATA_MDR, static_cast<unsigned char>(PAYLOAD_CMD::EQ_RET))) {
			ProtocolParser::applyEqualizer(nextStatus, *payload);
			if (nextStatus.hasEqualizer) {
				std::lock_guard guard(this->_propertyMtx);
				this->_eqPreset.current = static_cast<EQ_PRESET>(nextStatus.eqPresetCode);
				this->_eqPreset.desired = this->_eqPreset.current;
			}
		}
	}

	if (this->_capabilities.supportsVirtualSound) {
		const Buffer soundQuery = {
			static_cast<char>(COMMAND_TYPE::VPT_GET_PARAM),
			0x01
		};
		if (auto payload = this->_conn.sendQuery(soundQuery, DATA_TYPE::DATA_MDR, static_cast<unsigned char>(PAYLOAD_CMD::SOUND_RET))) {
			ProtocolParser::applyVirtualSound(*this, *payload);
		}

		const Buffer soundPosQuery = {
			static_cast<char>(COMMAND_TYPE::VPT_GET_PARAM),
			0x02
		};
		if (auto payload = this->_conn.sendQuery(soundPosQuery, DATA_TYPE::DATA_MDR, static_cast<unsigned char>(PAYLOAD_CMD::SOUND_RET))) {
			ProtocolParser::applyVirtualSound(*this, *payload);
		}
	}

	if (this->_capabilities.supportsTouchSensor) {
		const Buffer touchQuery = {
			static_cast<char>(PAYLOAD_CMD::TOUCH_GET),
			static_cast<char>(GS_INQUIRED_TYPE::GENERAL_SETTING2)
		};
		if (auto payload = this->_conn.sendQuery(touchQuery, DATA_TYPE::DATA_MDR, static_cast<unsigned char>(PAYLOAD_CMD::TOUCH_RET))) {
			ProtocolParser::applyTouchSensor(nextStatus, *payload);
			if (nextStatus.hasTouchSensor) {
				std::lock_guard guard(this->_propertyMtx);
				this->_touchSensorEnabled.current = nextStatus.touchSensorEnabled;
				this->_touchSensorEnabled.desired = this->_touchSensorEnabled.current;
			}
		}
	}

	if (this->_capabilities.supportsVoiceGuidance) {
		const Buffer voiceQuery = {
			static_cast<char>(VOICE_GUIDANCE_CMD::GET_PARAM),
			static_cast<char>(VOICE_GUIDANCE_INQUIRED::VOICE_GUIDANCE_SETTING),
			static_cast<char>(VOICE_GUIDANCE_INQUIRED::VOICE_GUIDANCE_SETTING)
		};
		if (auto payload = this->_conn.sendQuery(voiceQuery, DATA_TYPE::DATA_MDR_NO2, static_cast<unsigned char>(VOICE_GUIDANCE_CMD::RET_PARAM))) {
			ProtocolParser::applyVoiceGuidance(nextStatus, *payload);
			if (nextStatus.hasVoiceGuidance) {
				std::lock_guard guard(this->_propertyMtx);
				this->_voiceGuidanceEnabled.current = nextStatus.voiceGuidanceEnabled;
				this->_voiceGuidanceEnabled.desired = this->_voiceGuidanceEnabled.current;
			}
		}
	}

	nextStatus.modelName = this->_deviceStatus.modelName;
	nextStatus.protocolLabel = this->_deviceStatus.protocolLabel;
	this->_deviceStatus = nextStatus;
	return nextStatus.hasBattery || nextStatus.hasCodec || nextStatus.hasEqualizer;
}

bool Headphones::isChanged()
{
	const bool virtualSoundOk = !this->_capabilities.supportsVirtualSound
		|| (this->_surroundPosition.isFulfilled() && this->_vptType.isFulfilled());
	const bool eqOk = !this->_capabilities.supportsEqualizer || this->_eqPreset.isFulfilled();
	const bool touchOk = !this->_capabilities.supportsTouchSensor || this->_touchSensorEnabled.isFulfilled();
	const bool voiceOk = !this->_capabilities.supportsVoiceGuidance || this->_voiceGuidanceEnabled.isFulfilled();

	return !(this->_ambientSoundControl.isFulfilled() && this->_asmLevel.isFulfilled() && this->_focusOnVoice.isFulfilled()
		&& virtualSoundOk && eqOk && touchOk && voiceOk);
}

void Headphones::setChanges()
{
	if (!(this->_ambientSoundControl.isFulfilled() && this->_focusOnVoice.isFulfilled() && this->_asmLevel.isFulfilled()))
	{
		const char asmLevel = this->_ambientSoundControl.desired
			? static_cast<char>(std::min(this->_asmLevel.desired, this->_capabilities.asmMaxLevel))
			: static_cast<char>(ASM_LEVEL_DISABLED);

		if (this->_capabilities.usesV2AmbientSound) {
			this->_conn.sendCommand(CommandSerializer::serializeAmbientSoundControlV2(
				this->_ambientSoundControl.desired,
				this->_focusOnVoice.desired,
				asmLevel,
				this->_capabilities.supportsWindNoiseMode
			));
		} else {
			auto ncAsmEffect = this->_ambientSoundControl.desired ? NC_ASM_EFFECT::ADJUSTMENT_COMPLETION : NC_ASM_EFFECT::OFF;
			auto asmId = this->_focusOnVoice.desired ? ASM_ID::VOICE : ASM_ID::NORMAL;

			this->_conn.sendCommand(CommandSerializer::serializeNcAndAsmSetting(
				ncAsmEffect,
				NC_ASM_SETTING_TYPE::LEVEL_ADJUSTMENT,
				ASM_SETTING_TYPE::LEVEL_ADJUSTMENT,
				asmId,
				asmLevel,
				this->_capabilities.asmMaxLevel
			));
		}

		std::lock_guard guard(this->_propertyMtx);
		this->_ambientSoundControl.fulfill();
		this->_asmLevel.fulfill();
		this->_focusOnVoice.fulfill();
	}

	if (this->_capabilities.supportsVirtualSound && !(this->_vptType.isFulfilled() && this->_surroundPosition.isFulfilled())) {
		VPT_INQUIRED_TYPE command = VPT_INQUIRED_TYPE::VPT;
		unsigned char preset = 0;

		if (this->_vptType.desired != 0) {
			command = VPT_INQUIRED_TYPE::VPT;
			preset = static_cast<unsigned char>(this->_vptType.desired);
		} else if (this->_surroundPosition.desired != SOUND_POSITION_PRESET::OFF) {
			command = VPT_INQUIRED_TYPE::SOUND_POSITION;
			preset = static_cast<unsigned char>(this->_surroundPosition.desired);
		} else if (this->_surroundPosition.current != SOUND_POSITION_PRESET::OFF) {
			command = VPT_INQUIRED_TYPE::SOUND_POSITION;
			preset = static_cast<unsigned char>(SOUND_POSITION_PRESET::OFF);
		} else if (this->_vptType.current != 0) {
			command = VPT_INQUIRED_TYPE::VPT;
			preset = 0;
		}

		this->_conn.sendCommand(CommandSerializer::serializeVPTSetting(command, preset));

		std::lock_guard guard(this->_propertyMtx);
		this->_vptType.fulfill();
		this->_surroundPosition.fulfill();
	}

	if (this->_capabilities.supportsEqualizer && !this->_eqPreset.isFulfilled()) {
		this->_conn.sendCommand(CommandSerializer::serializeEqualizerPreset(this->_eqPreset.desired));
		std::lock_guard guard(this->_propertyMtx);
		this->_eqPreset.fulfill();
	}

	if (this->_capabilities.supportsTouchSensor && !this->_touchSensorEnabled.isFulfilled()) {
		this->_conn.sendCommand(CommandSerializer::serializeTouchSensor(this->_touchSensorEnabled.desired));
		std::lock_guard guard(this->_propertyMtx);
		this->_touchSensorEnabled.fulfill();
	}

	if (this->_capabilities.supportsVoiceGuidance && !this->_voiceGuidanceEnabled.isFulfilled()) {
		this->_conn.sendCommand(
			CommandSerializer::serializeVoiceGuidance(this->_voiceGuidanceEnabled.desired),
			DATA_TYPE::DATA_MDR_NO2);
		std::lock_guard guard(this->_propertyMtx);
		this->_voiceGuidanceEnabled.fulfill();
	}
}
