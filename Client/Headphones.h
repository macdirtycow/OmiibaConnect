#pragma once

#include "SingleInstanceFuture.h"
#include "BluetoothWrapper.h"
#include "Constants.h"
#include "DeviceStatus.h"

#include <mutex>

template <class T>
struct Property {
	T current;
	T desired;

	void fulfill();
	bool isFulfilled();
};

class Headphones {
public:
	Headphones(BluetoothWrapper& conn);

	void setAmbientSoundControl(bool val);
	bool getAmbientSoundControl();

	bool isFocusOnVoiceAvailable();
	void setFocusOnVoice(bool val);
	bool getFocusOnVoice();

	bool isSetAsmLevelAvailable();
	void setAsmLevel(int val);
	int getAsmLevel();

	void setSurroundPosition(SOUND_POSITION_PRESET val);
	SOUND_POSITION_PRESET getSurroundPosition();

	void setVptType(int val);
	int getVptType();

	void setEqualizerPreset(EQ_PRESET preset);
	EQ_PRESET getEqualizerPreset() const;

	void setTouchSensorEnabled(bool enabled);
	bool getTouchSensorEnabled() const;

	void setVoiceGuidanceEnabled(bool enabled);
	bool getVoiceGuidanceEnabled() const;

	const DeviceStatus& getDeviceStatus() const;

	bool performConnectHandshake();
	bool refreshFromDevice();
	bool isChanged();
	void setChanges();

	void applyDeviceState(bool ambientEnabled, bool focusOnVoice, int asmLevel);
	void applyDeviceVpt(int vptType);
	void applyDeviceSurroundPosition(SOUND_POSITION_PRESET preset);
private:
	Property<bool> _ambientSoundControl = { 0 };
	Property<bool> _focusOnVoice = { 0 };
	Property<int> _asmLevel = { 0 };
	Property<SOUND_POSITION_PRESET> _surroundPosition = { SOUND_POSITION_PRESET::OUT_OF_RANGE, SOUND_POSITION_PRESET::OFF };
	Property<int> _vptType = { 0 };
	Property<EQ_PRESET> _eqPreset = { EQ_PRESET::OFF };
	Property<bool> _touchSensorEnabled = { true };
	Property<bool> _voiceGuidanceEnabled = { true };
	std::mutex _propertyMtx;

	DeviceStatus _deviceStatus;
	BluetoothWrapper& _conn;
};

template<class T>
inline void Property<T>::fulfill()
{
	this->current = this->desired;
}

template<class T>
inline bool Property<T>::isFulfilled()
{
	return this->desired == this->current;
}
