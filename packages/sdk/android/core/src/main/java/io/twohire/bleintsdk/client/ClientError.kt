package io.twohire.bleintsdk.client

import io.twohire.bleintsdk.protocol.WritableTLState
import io.twohire.bleintsdk.utils.ErrorDescription

enum class ClientError : ErrorDescription {
    INVALID_DATA {
        override val description: String
            get() = "Client invalid data received"
    },
    INVALID_STATE {
        override val description: String
            get() = "Client invalid state"
    },
    INVALID_SESSION {
        override val description: String
            get() = "Client invalid session"
    },
    INVALID_COMMAND {
        override val description: String
            get() = "Client invalid command"
    };
}