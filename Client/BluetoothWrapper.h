#pragma once

#include "IBluetoothConnector.h"
#include "CommandSerializer.h"
#include "Constants.h"
#include <memory>
#include <vector>
#include <string>
#include <mutex>
#include <optional>


//Thread-safety: This class is thread-safe.
class BluetoothWrapper
{
public:
	BluetoothWrapper(std::unique_ptr<IBluetoothConnector> connector);

	BluetoothWrapper(const BluetoothWrapper&) = delete;
	BluetoothWrapper& operator=(const BluetoothWrapper&) = delete;

	BluetoothWrapper(BluetoothWrapper&& other) noexcept;
	BluetoothWrapper& operator=(BluetoothWrapper&& other) noexcept;

	int sendCommand(const std::vector<char>& bytes, DATA_TYPE dataType = DATA_TYPE::DATA_MDR);
	std::optional<Buffer> sendQuery(
		const Buffer& payloadBytes,
		DATA_TYPE dataType,
		unsigned char expectedRetCode,
		int maxMessages = 12
	);

	bool isConnected() noexcept;
	//Try to connect to the headphones
	void connect(const std::string& addr);
	void disconnect() noexcept;

	std::vector<BluetoothDevice> getConnectedDevices();

private:
	CommandSerializer::Message _recvFramedMessage();
	void _waitForAck();

	std::unique_ptr<IBluetoothConnector> _connector;
	std::mutex _connectorMtx;
	unsigned int _seqNumber = 0;
};
