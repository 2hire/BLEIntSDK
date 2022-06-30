package io.twohire.bleintsdk.bluetooth

internal enum class BluetoothError {
    NOT_CONNECTED,
    PERIPHERAL_NOT_FOUND,
    NOT_READING,
    TIMEOUT_ERROR,
    ADAPTER_NOT_ENABLED,
    GENERIC
}