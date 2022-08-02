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
    };
}

private val InvalidSessionStateFlow = listOf(
    listOf(
        WritableTLState.Writing,
        WritableTLState.Connected,
        WritableTLState.Reading,
        WritableTLState.Errored
    ),
    listOf(
        WritableTLState.Reading,
        WritableTLState.Errored,
        WritableTLState.Unknown
    ),
    listOf(
        WritableTLState.Connected,
        WritableTLState.Reading,
        WritableTLState.Unknown,
        WritableTLState.Errored
    )
)

internal fun checkInvalidSession(states: List<WritableTLState>): Boolean {
    for (it in InvalidSessionStateFlow.listIterator()) {
        val last = states.takeLast(it.size)

        if (last.size == it.size) {
            var match = true

            for (item in last.withIndex()) {
                if (it[item.index].ordinal != item.value.ordinal) {
                    match = false
                    break
                }
            }

            if (match) {
                return true
            }
        }
    }

    return false
}