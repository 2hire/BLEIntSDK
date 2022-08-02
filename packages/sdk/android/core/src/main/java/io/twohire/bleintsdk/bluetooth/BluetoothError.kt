package io.twohire.bleintsdk.bluetooth

import io.twohire.bleintsdk.utils.ErrorDescription

internal enum class BluetoothError : ErrorDescription {
    NOT_CONNECTED {
        override val description: String
            get() = "Bluetooth is not in connected state"
    },
    PERIPHERAL_NOT_FOUND {
        override val description: String
            get() = "Bluetooth peripheral not found"
    },
    NOT_READING {
        override val description: String
            get() = "Bluetooth is not reading"
    },
    TIMEOUT_ERROR {
        override val description: String
            get() = "Bluetooth timeout error"
    },
    ADAPTER_NOT_ENABLED {
        override val description: String
            get() = "Bluetooth adapter is not enabled"
    },
    GENERIC {
        override val description: String
            get() = "Bluetooth generic error"
    }
}