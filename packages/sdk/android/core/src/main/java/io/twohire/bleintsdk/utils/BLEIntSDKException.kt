package io.twohire.bleintsdk.utils

import io.twohire.bleintsdk.bluetooth.BluetoothError
import io.twohire.bleintsdk.client.ClientError

class BLEIntSDKException(val error: BLEIntError): Exception()

interface ErrorDescription {
    val description: String
}

enum class BLEIntError: ErrorDescription {
    INVALID_DATA {
        override val code: String
            get() = "invalid_data"
        override val description: String
            get() = ClientError.INVALID_DATA.description
    },
    INVALID_STATE {
        override val code: String
            get() = "invalid_state"
        override val description: String
            get() = ClientError.INVALID_STATE.description
    },
    INVALID_SESSION {
        override val code: String
            get() = "invalid_session"
        override val description: String
            get() = ClientError.INVALID_SESSION.description
    },
    NOT_CONNECTED {
        override val code: String
            get() = "not_connected"
        override val description: String
            get() = BluetoothError.NOT_CONNECTED.description
    },
    TIMEOUT {
        override val code: String
            get() = "timeout"
        override val description: String
            get() = BluetoothError.TIMEOUT_ERROR.description
    },
    PERIPHERAL_NOT_FOUND {
        override val code: String
            get() = "peripheral_not_found"
        override val description: String
            get() = BluetoothError.PERIPHERAL_NOT_FOUND.description
    },
    INTERNAL {
        override val code: String
            get() = "internal"
        override val description: String
            get() = "Internal Error"
    };

    abstract val code: String

    companion object {
        internal fun fromError(error: String?): BLEIntError {
            return when (error) {
                ClientError.INVALID_DATA.name -> INVALID_DATA
                ClientError.INVALID_STATE.name -> INVALID_STATE
                ClientError.INVALID_SESSION.name -> INVALID_SESSION
                BluetoothError.NOT_CONNECTED.name -> NOT_CONNECTED
                BluetoothError.TIMEOUT_ERROR.name -> TIMEOUT
                BluetoothError.PERIPHERAL_NOT_FOUND.name -> PERIPHERAL_NOT_FOUND
                else -> INTERNAL
            }
        }
    }
}