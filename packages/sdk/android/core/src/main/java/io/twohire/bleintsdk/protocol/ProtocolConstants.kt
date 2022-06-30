package io.twohire.bleintsdk.protocol

internal object ProtocolConstants {
    val START_SEQUENCE = byteArrayOf(
        0xC1.toByte(), 0xA0.toByte(), 0xC1.toByte(), 0xA0.toByte()
    )

    val END_SEQUENCE = byteArrayOf(0xE2.toByte(), 0x1B.toByte(), 0xE7.toByte(), 0x7A.toByte())

    const val ACK = 0xF0.toByte()
    const val NACK = 0xF1.toByte()
}

internal object ProtocolMessageType {
    const val REQUEST = 0xAA.toByte()
    const val RESPONSE = 0x55.toByte()
}

internal const val PROTOCOL_VERSION = 0x01.toByte()
