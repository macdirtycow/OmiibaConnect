#pragma once
#include <stdio.h>
#include "../IBluetoothConnector.h"
#include "IOBluetooth/IOBluetooth.h"
#include "Constants.h"
#include <thread>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <deque>
#include <future>

class MacOSBluetoothConnector final : public IBluetoothConnector
{
public:
    MacOSBluetoothConnector();
    ~MacOSBluetoothConnector();
    static void connectToMac(MacOSBluetoothConnector* connector) noexcept;
    void handleRfcommOpenComplete(IOBluetoothRFCOMMChannel* channel, IOReturn status) noexcept;
    void discardPendingReceive() noexcept;
    void setBlockingRecv(bool blocking) noexcept override;
    virtual void connect(const std::string& addrStr) noexcept(false);
    virtual int send(char* buf, size_t length) noexcept(false);
    virtual int recv(char* buf, size_t length) noexcept(false);
    virtual void disconnect() noexcept;
    virtual bool isConnected() noexcept;
    virtual void closeConnection();

    virtual std::vector<BluetoothDevice> getConnectedDevices() noexcept(false);

    std::deque<std::vector<unsigned char>> receivedBytes;
    std::mutex receiveDataMutex;
    std::condition_variable receiveDataConditionVariable;
    std::atomic<bool> running{false};
    std::mutex disconnectionMutex;
    std::condition_variable disconnectionConditionVariable;

    void finishConnectSuccess() noexcept;
    void finishConnectFailure(const char* message) noexcept;
    bool tryFinishConnectOnce() noexcept;

private:
    std::unique_ptr<std::promise<void>> _connectPromise;
    std::mutex _connectPromiseMtx;
    std::atomic<bool> _connectFinished{false};
    std::atomic<bool> _blockingRecv{false};
    void* rfcommDevice = nullptr;
    void* rfcommchannel = nullptr;
    void* commDelegate = nullptr; // __bridge_retained
    std::thread uthread;
};
