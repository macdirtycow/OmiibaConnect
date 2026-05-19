#pragma once

#include "IBluetoothConnector.h"
#include "CommandSerializer.h"
#include "Constants.h"
#include <memory>
#include <vector>
#include <string>
#include <mutex>
#include <optional>
#include <initializer_list>
#include <chrono>


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
	std::optional<Buffer> sendQuery(
		const Buffer& payloadBytes,
		DATA_TYPE dataType,
		std::initializer_list<unsigned char> expectedRetCodes,
		int maxMessages = 12
	);

	bool isConnected() noexcept;
	void connect(const std::string& addr);
	void disconnect() noexcept;

	std::vector<BluetoothDevice> getConnectedDevices();

private:
	std::optional<CommandSerializer::Message> _tryRecvFramedMessage();
	void _sendAck(unsigned char deviceSeqNumber);
	void _waitForAck();
	bool _tryWaitForAckAfterSend();
	unsigned char _nextSendSequence();
	void _onAckReceived(unsigned char ackSeq);
	void _drainIncomingMessages(std::chrono::milliseconds duration);

	std::unique_ptr<IBluetoothConnector> _connector;
	std::mutex _connectorMtx;
	unsigned char _seqNumber = 0;
	Buffer _recvStaging;
	bool _recvInMessage = false;
};
