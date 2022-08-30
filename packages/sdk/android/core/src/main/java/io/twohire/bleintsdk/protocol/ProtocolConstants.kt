package io.twohire.bleintsdk.protocol

internal enum class ProtocolFrame(val rawValue: ByteArray) {
    SESSION_START(
        byteArrayOf(
            0xC1.toByte(), 0xA0.toByte(), 0xC1.toByte(), 0xA0.toByte()
        )
    ),
    SESSION_END(byteArrayOf(0xE2.toByte(), 0x1B.toByte(), 0xE7.toByte(), 0x7A.toByte())),
    COMMAND_START(byteArrayOf(0xE2.toByte(), 0x2A.toByte(), 0xDA.toByte(), 0xDA.toByte())),
    COMMAND_END(byteArrayOf(0xE2.toByte(), 0x1B.toByte(), 0xE7.toByte(), 0x7A.toByte()))
}

internal object ProtocolMessageType {
    const val REQUEST = 0xAA.toByte()
    const val RESPONSE = 0x55.toByte()
}

internal const val PROTOCOL_VERSION = 0x01.toByte()

internal enum class CommandIdentifier(val rawValue: Byte) {
    ACK(0xF0.toByte()),
    NACK(0xF1.toByte()),
    ERROR(0xF2.toByte());

    companion object {
        fun fromRaw(rawValue: Byte) = values().firstOrNull { it.rawValue == rawValue }
    }
}

internal enum class ProtocolPacketType(val rawValue: Byte) {
    REQUEST(0xAA.toByte()),
    RESPONSE(0x55.toByte());

    companion object {
        fun fromRaw(rawValue: Byte) = values().firstOrNull { it.rawValue == rawValue }
    }
}

internal enum class ProtocolErrorCode(val rawValue: Byte) {
    ALREADY_VALIDATED(0x01.toByte()),
    INVALID_ACCESS(0xFF.toByte()),
    INVALID_TIMESTAMP(0xFE.toByte()),
    INVALID_TAG(0xFD.toByte()),
    INVALID_COUNTER(0xFC.toByte()),
    INVALID_CMD(0xFB.toByte()),
    INVALID_START_BYTE(0xFA.toByte()),
    UNKNOWN_VERSION(0xF9.toByte()),
    INVALID_CMD_TAG(0xF8.toByte()),
    INVALID_LENGTH(0xF7.toByte());

    companion object {
        fun fromRaw(rawValue: Byte) = values().firstOrNull { it.rawValue == rawValue }
    }
}
