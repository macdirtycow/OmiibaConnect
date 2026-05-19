#include "BluetoothWrapper.h"

BluetoothWrapper::BluetoothWrapper(std::unique_ptr<IBluetoothConnector> connector)
{
	this->_connector.swap(connector);
}

BluetoothWrapper::BluetoothWrapper(BluetoothWrapper&& other) noexcept
{
	this->_connector.swap(other._connector);
	this->_seqNumber = other._seqNumber;
}

BluetoothWrapper& BluetoothWrapper::operator=(BluetoothWrapper&& other) noexcept
{
	//self assignment
	if (this == &other) return *this;

	this->_connector.swap(other._connector);
	this->_seqNumber = other._seqNumber;

	return *this;
}

int BluetoothWrapper::sendCommand(const std::vector<char>& bytes, DATA_TYPE dataType)
{
	std::lock_guard guard(this->_connectorMtx);
	auto data = CommandSerializer::packageDataForBt(bytes, dataType, this->_seqNumber++);
	auto bytesSent = this->_connector->send(data.data(), data.size());

	this->_waitForAck();

	return bytesSent;
}

std::optional<Buffer> BluetoothWrapper::sendQuery(
	const Buffer& payloadBytes,
	DATA_TYPE dataType,
	unsigned char expectedRetCode,
	int maxMessages)
{
	std::lock_guard guard(this->_connectorMtx);
	auto data = CommandSerializer::packageDataForBt(payloadBytes, dataType, this->_seqNumber++);
	this->_connector->send(data.data(), data.size());

	for (int i = 0; i < maxMessages; i++) {
		auto msg = this->_recvFramedMessage();
		if (msg.dataType == DATA_TYPE::ACK) {
			continue;
		}
		if (msg.dataType == dataType && !msg.payload.empty() && static_cast<unsigned char>(msg.payload[0]) == expectedRetCode) {
			return msg.payload;
		}
	}

	return std::nullopt;
}

bool BluetoothWrapper::isConnected() noexcept
{
	return this->_connector->isConnected();
}

void BluetoothWrapper::connect(const std::string& addr)
{
	std::lock_guard guard(this->_connectorMtx);
	this->_connector->connect(addr);
}

void BluetoothWrapper::disconnect() noexcept
{
	std::lock_guard guard(this->_connectorMtx);
	this->_seqNumber = 0;
	this->_connector->disconnect();
}


std::vector<BluetoothDevice> BluetoothWrapper::getConnectedDevices()
{
	return this->_connector->getConnectedDevices();
}

CommandSerializer::Message BluetoothWrapper::_recvFramedMessage()
{
	bool ongoingMessage = false;
	bool messageFinished = false;
	char buf[MAX_BLUETOOTH_MESSAGE_SIZE] = { 0 };
	Buffer msgBytes;

	do
	{
		auto numRecvd = this->_connector->recv(buf, sizeof(buf));
		size_t messageStart = 0;
		size_t messageEnd = numRecvd;

		for (size_t i = 0; i < numRecvd; i++)
		{
			if (buf[i] == START_MARKER)
			{
				if (ongoingMessage)
				{
					throw RecoverableException("Invalid: Multiple start markers without an end marker", true);
				}
				messageStart = i + 1;
				ongoingMessage = true;
			}
			else if (ongoingMessage && buf[i] == END_MARKER)
			{
				messageEnd = i;
				ongoingMessage = false;
				messageFinished = true;
			}
		}

		msgBytes.insert(msgBytes.end(), buf + messageStart, buf + messageEnd);
	} while (!messageFinished);

	auto msg = CommandSerializer::unpackBtMessage(msgBytes);
	this->_seqNumber = msg.seqNumber;
	return msg;
}

void BluetoothWrapper::_waitForAck()
{
	for (int i = 0; i < 8; i++) {
		auto msg = this->_recvFramedMessage();
		if (msg.dataType == DATA_TYPE::ACK) {
			return;
		}
	}
	throw RecoverableException("Did not receive ACK from headphones", true);
}
