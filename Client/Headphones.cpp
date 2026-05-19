#include "Headphones.h"
#include "CommandSerializer.h"
#include "ProtocolParser.h"

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
	// Sony | Sound Connect always sends CONNECT_GET_PROTOCOL_INFO first; without it
	// many GET commands return nothing (mdr-protocol / APK: tandemfamily.message.mdr).
	const Buffer protocolInfo = { static_cast<char>(PAYLOAD_CMD::CONNECT_GET_PROTOCOL_INFO) };
	this->_conn.sendQuery(
		protocolInfo,
		DATA_TYPE::DATA_MDR,
		static_cast<unsigned char>(PAYLOAD_CMD::CONNECT_RET_PROTOCOL_INFO)
	);

	const Buffer supportFn = { static_cast<char>(PAYLOAD_CMD::CONNECT_GET_SUPPORT_FUNCTION) };
	this->_conn.sendQuery(
		supportFn,
		DATA_TYPE::DATA_MDR,
		static_cast<unsigned char>(PAYLOAD_CMD::CONNECT_RET_SUPPORT_FUNCTION)
	);

	return true;
}

bool Headphones::refreshFromDevice()
{
	performConnectHandshake();

	DeviceStatus nextStatus;

	const Buffer ncQuery = {
		static_cast<char>(PAYLOAD_CMD::NCASM_GET),
		0x02
	};
	if (auto payload = this->_conn.sendQuery(ncQuery, DATA_TYPE::DATA_MDR, static_cast<unsigned char>(PAYLOAD_CMD::NCASM_RET))) {
		ProtocolParser::applyAmbientSoundControl(*this, *payload);
	}

	const Buffer batteryQuery = {
		static_cast<char>(PAYLOAD_CMD::BATTERY_REQUEST),
		0x00
	};
	if (auto payload = this->_conn.sendQuery(batteryQuery, DATA_TYPE::DATA_MDR, static_cast<unsigned char>(PAYLOAD_CMD::BATTERY_RET))) {
		if (auto level = ProtocolParser::parseBatteryPercent(*payload)) {
			nextStatus.batteryPercent = *level;
			nextStatus.hasBattery = true;
		}
	}

	const Buffer codecQuery = {
		static_cast<char>(PAYLOAD_CMD::AUDIO_CODEC_REQUEST),
		0x00
	};
	if (auto payload = this->_conn.sendQuery(codecQuery, DATA_TYPE::DATA_MDR, static_cast<unsigned char>(PAYLOAD_CMD::AUDIO_CODEC_RET))) {
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

	const Buffer eqQuery = { static_cast<char>(PAYLOAD_CMD::EQ_GET) };
	if (auto payload = this->_conn.sendQuery(eqQuery, DATA_TYPE::DATA_MDR, static_cast<unsigned char>(PAYLOAD_CMD::EQ_RET))) {
		ProtocolParser::applyEqualizer(nextStatus, *payload);
		if (nextStatus.hasEqualizer) {
			std::lock_guard guard(this->_propertyMtx);
			this->_eqPreset.current = static_cast<EQ_PRESET>(nextStatus.eqPresetCode);
			this->_eqPreset.desired = this->_eqPreset.current;
		}
	}

	const Buffer soundQuery = {
		static_cast<char>(PAYLOAD_CMD::SOUND_GET),
		0x01
	};
	if (auto payload = this->_conn.sendQuery(soundQuery, DATA_TYPE::DATA_MDR, static_cast<unsigned char>(PAYLOAD_CMD::SOUND_RET))) {
		ProtocolParser::applyVirtualSound(*this, *payload);
	}

	const Buffer soundPosQuery = {
		static_cast<char>(PAYLOAD_CMD::SOUND_GET),
		0x02
	};
	if (auto payload = this->_conn.sendQuery(soundPosQuery, DATA_TYPE::DATA_MDR, static_cast<unsigned char>(PAYLOAD_CMD::SOUND_RET))) {
		ProtocolParser::applyVirtualSound(*this, *payload);
	}

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

	this->_deviceStatus = nextStatus;
	return nextStatus.hasBattery || nextStatus.hasCodec || nextStatus.hasEqualizer;
}

bool Headphones::isChanged()
{
	return !(this->_ambientSoundControl.isFulfilled() && this->_asmLevel.isFulfilled() && this->_focusOnVoice.isFulfilled()
		&& this->_surroundPosition.isFulfilled() && this->_vptType.isFulfilled() && this->_eqPreset.isFulfilled()
		&& this->_touchSensorEnabled.isFulfilled() && this->_voiceGuidanceEnabled.isFulfilled());
}

void Headphones::setChanges()
{
	if (!(this->_ambientSoundControl.isFulfilled() && this->_focusOnVoice.isFulfilled() && this->_asmLevel.isFulfilled()))
	{
		auto ncAsmEffect = this->_ambientSoundControl.desired ? NC_ASM_EFFECT::ADJUSTMENT_COMPLETION : NC_ASM_EFFECT::OFF;
		auto asmId = this->_focusOnVoice.desired ? ASM_ID::VOICE : ASM_ID::NORMAL;
		auto asmLevel = this->_ambientSoundControl.desired ? this->_asmLevel.desired : ASM_LEVEL_DISABLED;

		this->_conn.sendCommand(CommandSerializer::serializeNcAndAsmSetting(
			ncAsmEffect,
			NC_ASM_SETTING_TYPE::LEVEL_ADJUSTMENT,
			ASM_SETTING_TYPE::LEVEL_ADJUSTMENT,
			asmId,
			asmLevel
		));
		
		std::lock_guard guard(this->_propertyMtx);
		this->_ambientSoundControl.fulfill();
		this->_asmLevel.fulfill();
		this->_focusOnVoice.fulfill();
	}

	if (!(this->_vptType.isFulfilled() && this->_surroundPosition.isFulfilled())) {
		VPT_INQUIRED_TYPE command;
		unsigned char preset;

		if (this->_vptType.desired != 0) {
			command = VPT_INQUIRED_TYPE::VPT;
			preset = static_cast<unsigned char>(this->_vptType.desired);
		}
		else if (this->_surroundPosition.desired != SOUND_POSITION_PRESET::OFF) {
			command = VPT_INQUIRED_TYPE::SOUND_POSITION;
			preset = static_cast<unsigned char>(this->_surroundPosition.desired);
		}
		else {
			if (this->_surroundPosition.current != SOUND_POSITION_PRESET::OFF) {
				command = VPT_INQUIRED_TYPE::SOUND_POSITION;
				preset = static_cast<unsigned char>(SOUND_POSITION_PRESET::OFF);
			}
			else if (this->_vptType.current != 0) {
				command = VPT_INQUIRED_TYPE::VPT;
				preset = 0;
			}
			else {
				throw std::logic_error("it's impossible that both values were changed to zero and were also previously zero");
			}
		}

		this->_conn.sendCommand(CommandSerializer::serializeVPTSetting(command, preset));

		std::lock_guard guard(this->_propertyMtx);
		this->_vptType.fulfill();
		this->_surroundPosition.fulfill();
	}

	if (!this->_eqPreset.isFulfilled()) {
		this->_conn.sendCommand(CommandSerializer::serializeEqualizerPreset(this->_eqPreset.desired));
		std::lock_guard guard(this->_propertyMtx);
		this->_eqPreset.fulfill();
	}

	if (!this->_touchSensorEnabled.isFulfilled()) {
		this->_conn.sendCommand(CommandSerializer::serializeTouchSensor(this->_touchSensorEnabled.desired));
		std::lock_guard guard(this->_propertyMtx);
		this->_touchSensorEnabled.fulfill();
	}

	if (!this->_voiceGuidanceEnabled.isFulfilled()) {
		this->_conn.sendCommand(
			CommandSerializer::serializeVoiceGuidance(this->_voiceGuidanceEnabled.desired),
			DATA_TYPE::DATA_MDR_NO2
		);
		std::lock_guard guard(this->_propertyMtx);
		this->_voiceGuidanceEnabled.fulfill();
	}
}
