#include "MacOSBluetoothConnector.h"
#include "../Exceptions.h"

#include <chrono>

@interface AsyncCommDelegate : NSObject <IOBluetoothRFCOMMChannelDelegate> {
@public
    MacOSBluetoothConnector* delegateCPP;
}
@end

@implementation AsyncCommDelegate
- (void)rfcommChannelOpenComplete:(IOBluetoothRFCOMMChannel*)rfcommChannel status:(IOReturn)errorCode
{
    if (delegateCPP == nullptr) {
        return;
    }
    delegateCPP->handleRfcommOpenComplete(rfcommChannel, errorCode);
}

- (void)rfcommChannelClosed:(IOBluetoothRFCOMMChannel*)rfcommChannel
{
    (void)rfcommChannel;
    if (delegateCPP == nullptr) {
        return;
    }
    delegateCPP->running = false;
    delegateCPP->disconnectionConditionVariable.notify_all();
}

- (void)rfcommChannelData:(IOBluetoothRFCOMMChannel*)rfcommChannel data:(void*)dataPointer length:(size_t)dataLength
{
    (void)rfcommChannel;
    if (delegateCPP == nullptr) {
        return;
    }

    std::lock_guard<std::mutex> g(delegateCPP->receiveDataMutex);

    const auto* buffer = static_cast<const unsigned char*>(dataPointer);
    std::vector<unsigned char> vectorBuffer(buffer, buffer + dataLength);

    delegateCPP->receivedBytes.push_back(std::move(vectorBuffer));
    delegateCPP->receiveDataConditionVariable.notify_one();
}
@end

MacOSBluetoothConnector::MacOSBluetoothConnector() = default;

MacOSBluetoothConnector::~MacOSBluetoothConnector()
{
    disconnect();
}

bool MacOSBluetoothConnector::tryFinishConnectOnce() noexcept
{
    bool expected = false;
    if (!_connectFinished.compare_exchange_strong(expected, true)) {
        return false;
    }
    finishConnectSuccess();
    return true;
}

void MacOSBluetoothConnector::finishConnectSuccess() noexcept
{
    std::lock_guard<std::mutex> lk(_connectPromiseMtx);
    if (!_connectPromise) {
        return;
    }
    try {
        _connectPromise->set_value();
    } catch (...) {
    }
    _connectPromise.reset();
}

void MacOSBluetoothConnector::finishConnectFailure(const char* message) noexcept
{
    bool expected = false;
    if (!_connectFinished.compare_exchange_strong(expected, true)) {
        return;
    }

    std::lock_guard<std::mutex> lk(_connectPromiseMtx);
    if (!_connectPromise) {
        return;
    }
    try {
        const RecoverableException exc(message, false);
        _connectPromise->set_exception(std::make_exception_ptr(exc));
    } catch (...) {
    }
    _connectPromise.reset();
}

void MacOSBluetoothConnector::handleRfcommOpenComplete(IOBluetoothRFCOMMChannel* channel, IOReturn status) noexcept
{
    if (_connectFinished.load()) {
        return;
    }
    if (status != kIOReturnSuccess) {
        finishConnectFailure("Could not open RFCOMM connection to headphones.");
        return;
    }
    if (channel == nil || !channel.isOpen) {
        return;
    }

    rfcommchannel = (__bridge void*)channel;
    running = true;
    tryFinishConnectOnce();
}

void MacOSBluetoothConnector::discardPendingReceive() noexcept
{
    std::lock_guard<std::mutex> g(receiveDataMutex);
    receivedBytes.clear();
}

void MacOSBluetoothConnector::setBlockingRecv(bool blocking) noexcept
{
    _blockingRecv.store(blocking);
}

int MacOSBluetoothConnector::send(char* buf, size_t length)
{
    auto* chan = (__bridge IOBluetoothRFCOMMChannel*)rfcommchannel;
    if (chan == nil || !chan.isOpen) {
        return 0;
    }
    const IOReturn result = [chan writeSync:buf length:length];
    if (result != kIOReturnSuccess) {
        return 0;
    }
    return static_cast<int>(length);
}

void MacOSBluetoothConnector::connectToMac(MacOSBluetoothConnector* connector) noexcept
{
    IOBluetoothRFCOMMChannel* channel = nil;

    try {
        IOBluetoothDevice* device = (__bridge IOBluetoothDevice*)connector->rfcommDevice;
        channel = [[IOBluetoothRFCOMMChannel alloc] init];

        IOBluetoothSDPUUID* sppServiceUUID = [IOBluetoothSDPUUID uuidWithBytes:(void*)SERVICE_UUID_IN_BYTES length:16];
        IOBluetoothSDPServiceRecord* sppServiceRecord = [device getServiceRecordForUUID:sppServiceUUID];

        if (sppServiceRecord == nil) {
            connector->finishConnectFailure(
                "Sony headset service not found. Connect the headphones in System Settings first.");
            return;
        }

        UInt8 rfcommChannelID = 0;
        if ([sppServiceRecord getRFCOMMChannelID:&rfcommChannelID] != kIOReturnSuccess) {
            connector->finishConnectFailure("Could not find the Sony headset Bluetooth channel.");
            return;
        }

        AsyncCommDelegate* asyncCommDelegate = [[AsyncCommDelegate alloc] init];
        asyncCommDelegate->delegateCPP = connector;
        connector->commDelegate = (__bridge_retained void*)asyncCommDelegate;

        if ([device openRFCOMMChannelAsync:&channel withChannelID:rfcommChannelID delegate:asyncCommDelegate]
            != kIOReturnSuccess) {
            connector->finishConnectFailure("Could not open RFCOMM connection to headphones.");
            return;
        }

        connector->rfcommchannel = (__bridge void*)channel;
        connector->running = true;

        const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(18);
        while (!connector->_connectFinished.load() && std::chrono::steady_clock::now() < deadline) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            if (channel != nil && channel.isOpen) {
                connector->tryFinishConnectOnce();
                break;
            }
        }

        if (!connector->_connectFinished.load()) {
            connector->finishConnectFailure(
                "Could not open RFCOMM connection to headphones. Try disconnecting in System Settings and reconnecting.");
            connector->running = false;
            return;
        }

        std::unique_lock<std::mutex> lk(connector->disconnectionMutex);
        while (connector->running.load()) {
            lk.unlock();
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            // Also spin main run loop — IOBluetooth may deliver RFCOMM data there after backgrounding.
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            });
            lk.lock();
            connector->disconnectionConditionVariable.wait_for(
                lk, std::chrono::milliseconds(100),
                [&]() { return !connector->running.load(); });
        }
    } catch (...) {
        connector->finishConnectFailure("Unexpected error while connecting to headphones.");
    }
}

void MacOSBluetoothConnector::connect(const std::string& addrStr)
{
    if (uthread.joinable()) {
        disconnect();
    }

    running = false;
    rfcommchannel = nullptr;
    _connectFinished = false;

    NSString* addressNSString = [NSString stringWithUTF8String:addrStr.c_str()];
    IOBluetoothDevice* device = [IOBluetoothDevice deviceWithAddressString:addressNSString];
    if (device == nil) {
        throw RecoverableException("Bluetooth device not found.", false);
    }

    if (![device isConnected]) {
        if ([device openConnection] != kIOReturnSuccess) {
            throw RecoverableException(
                "Could not open Bluetooth. Connect the headphones in System Settings first.",
                false);
        }
    }

    std::future<void> connectFuture;
    {
        std::lock_guard<std::mutex> lk(_connectPromiseMtx);
        _connectPromise = std::make_unique<std::promise<void>>();
        connectFuture = _connectPromise->get_future();
    }

    rfcommDevice = (__bridge void*)device;
    uthread = std::thread(MacOSBluetoothConnector::connectToMac, this);

    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(20);
    while (connectFuture.wait_for(std::chrono::milliseconds(50)) != std::future_status::ready) {
        if (std::chrono::steady_clock::now() >= deadline) {
            running = false;
            disconnectionConditionVariable.notify_all();
            {
                std::lock_guard<std::mutex> lk(_connectPromiseMtx);
                _connectPromise.reset();
            }
            _connectFinished = true;
            if (rfcommchannel != nullptr) {
                IOBluetoothRFCOMMChannel* chan = (__bridge IOBluetoothRFCOMMChannel*)rfcommchannel;
                [chan setDelegate:nil];
                if (chan.isOpen) {
                    [chan closeChannel];
                }
                rfcommchannel = nullptr;
            }
            if (uthread.joinable()) {
                uthread.join();
            }
            throw RecoverableException("Connection timed out.", false);
        }

        // IOBluetooth may deliver delegate callbacks on the main run loop.
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }

    try {
        connectFuture.get();
    } catch (const std::exception& exc) {
        running = false;
        disconnectionConditionVariable.notify_all();
        if (uthread.joinable()) {
            uthread.join();
        }
        throw RecoverableException(exc.what(), false);
    }

    discardPendingReceive();
}

int MacOSBluetoothConnector::recv(char* buf, size_t length)
{
    std::unique_lock<std::mutex> g(receiveDataMutex);
    const auto recvTimeout = _blockingRecv.load()
        ? std::chrono::milliseconds(12000)
        : std::chrono::milliseconds(3000);
    const bool gotData = receiveDataConditionVariable.wait_for(
        g,
        recvTimeout,
        [this] { return !receivedBytes.empty(); });
    if (!gotData || receivedBytes.empty()) {
        return 0;
    }

    std::vector<unsigned char> receivedVector = std::move(receivedBytes.front());
    receivedBytes.pop_front();

    const size_t lengthCopied = std::min(length, receivedVector.size());
    std::memcpy(buf, receivedVector.data(), lengthCopied);

    if (receivedVector.size() > lengthCopied) {
        receivedVector.erase(receivedVector.begin(), receivedVector.begin() + static_cast<long>(lengthCopied));
        receivedBytes.push_front(std::move(receivedVector));
    }

    return static_cast<int>(lengthCopied);
}

std::vector<BluetoothDevice> MacOSBluetoothConnector::getConnectedDevices()
{
    std::vector<BluetoothDevice> res;
    for (IOBluetoothDevice* device in [IOBluetoothDevice pairedDevices]) {
        if ([device isConnected]) {
            BluetoothDevice dev;
            dev.mac = [[device addressString] UTF8String];
            dev.name = [[device name] UTF8String];
            res.push_back(dev);
        }
    }
    return res;
}

void MacOSBluetoothConnector::serviceTransport() noexcept
{
    disconnectionConditionVariable.notify_all();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    });
}

void MacOSBluetoothConnector::disconnect() noexcept
{
    const bool onWorkerThread = uthread.joinable() && std::this_thread::get_id() == uthread.get_id();

    running = false;
    _connectFinished = true;

    {
        std::lock_guard<std::mutex> lk(_connectPromiseMtx);
        _connectPromise.reset();
    }

    if (rfcommchannel != nullptr) {
        IOBluetoothRFCOMMChannel* chan = (__bridge IOBluetoothRFCOMMChannel*)rfcommchannel;
        [chan setDelegate:nil];
        if (chan.isOpen) {
            [chan closeChannel];
        }
        rfcommchannel = nullptr;
    }

    if (commDelegate != nullptr) {
        AsyncCommDelegate* delegate = (__bridge_transfer AsyncCommDelegate*)commDelegate;
        delegate->delegateCPP = nullptr;
        commDelegate = nullptr;
        (void)delegate;
    }

    disconnectionConditionVariable.notify_all();

    if (!onWorkerThread && uthread.joinable()) {
        uthread.join();
    }

    rfcommDevice = nullptr;
    discardPendingReceive();
}

void MacOSBluetoothConnector::closeConnection()
{
    if (rfcommchannel == nullptr) {
        return;
    }

    IOBluetoothRFCOMMChannel* chan = (__bridge IOBluetoothRFCOMMChannel*)rfcommchannel;
    [chan setDelegate:nil];
    if (chan.isOpen) {
        [chan closeChannel];
    }
    rfcommchannel = nullptr;
}

bool MacOSBluetoothConnector::isConnected() noexcept
{
    if (!running.load()) {
        return false;
    }
    if (rfcommchannel == nullptr) {
        return false;
    }
    IOBluetoothRFCOMMChannel* chan = (__bridge IOBluetoothRFCOMMChannel*)rfcommchannel;
    return chan.isOpen;
}
