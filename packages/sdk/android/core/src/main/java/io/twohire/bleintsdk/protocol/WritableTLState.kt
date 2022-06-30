package io.twohire.bleintsdk.protocol

internal enum class WritableTLState {
    Reading,
    Writing,
    Connected,
    Created,
    Errored,
    Unknown;

    companion object {
        fun fromName(name: String): WritableTLState? {
            return try {
                java.lang.Enum.valueOf(WritableTLState::class.java, name)
            } catch (e: Exception) {
                null
            }
        }
    }
}