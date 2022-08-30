package io.twohire.bleintsdk.protocol

import io.twohire.bleintsdk.crypto.CryptoHelper
import io.twohire.bleintsdk.crypto.SealedBox
import java.security.PrivateKey
import java.security.PublicKey

internal interface CodableBytes {
    fun encode(): ByteArray
}

internal interface Payload : CodableBytes {
    val data: ByteArray
}

internal interface ProtocolPacket : Payload {
    val version: Byte
}

internal data class EncryptedCommandPacket(
    override val version: Byte, override val data: ByteArray, private val nonce: ByteArray,
    private val tag: ByteArray
) : ProtocolPacket {

    companion object {
        fun encrypt(
            data: ByteArray,
            version: Byte,
            privateKey: PrivateKey,
            publicKey: PublicKey
        ): EncryptedCommandPacket {
            val sealedBox = CryptoHelper.encrypt(data, privateKey, publicKey)

            return EncryptedCommandPacket(version, sealedBox.data, sealedBox.nonce, sealedBox.tag)
        }

        fun create(from: ByteArray): EncryptedCommandPacket {
            val version = from[0]
            val nonce = from.slice(1 until 17).toByteArray()
            val tag = from.slice(17 until 33).toByteArray()
            val data = from.drop(33).toByteArray()

            return EncryptedCommandPacket(version, data, nonce, tag)
        }
    }

    fun decrypt(privateKey: PrivateKey, publicKey: PublicKey): ByteArray {
        val sealedBox = SealedBox(this.data, this.nonce, this.tag)

        return CryptoHelper.decrypt(sealedBox, privateKey, publicKey)
    }

    override fun encode(): ByteArray {
        var packet = byteArrayOf(this.version)

        packet += this.nonce
        packet += this.tag
        packet += this.data

        return packet
    }
}

internal data class CommandResponsePayload(override val data: ByteArray, val commandIdentifier: CommandIdentifier) : Payload {
    companion object {
        fun create(from: ByteArray): CommandResponsePayload {
            val messageType = ProtocolPacketType.fromRaw(from[0])
            val commandIdentifier = CommandIdentifier.fromRaw(from[5])
            val data = from.drop(6).toByteArray()

           if (commandIdentifier == null || messageType != ProtocolPacketType.RESPONSE) {
                throw IllegalStateException(ProtocolError.INVALID_DATA.name)
            }

            return CommandResponsePayload(data, commandIdentifier)
           }
        }

    override fun encode(): ByteArray {
        var packet = byteArrayOf(ProtocolPacketType.RESPONSE.rawValue)

        packet += getTimestamp()
        packet += this.commandIdentifier.rawValue
        packet += this.data

        return packet
    }
}

internal data class ErrorCommandPayload(val errorCode: ProtocolErrorCode): CodableBytes {
    companion object {
        fun create(from: ByteArray): ErrorCommandPayload {
            val value = ProtocolErrorCode.fromRaw(from[0])
                ?: throw IllegalStateException(ProtocolError.INVALID_DATA.name)

            return ErrorCommandPayload(value)
        }
    }
    override fun encode(): ByteArray {
        return byteArrayOf(this.errorCode.rawValue)
    }
}

internal data class CommandRequestPayload(override val data: ByteArray): Payload {
    companion object {
        fun create(from: ByteArray): CommandRequestPayload {
            val value = ProtocolPacketType.fromRaw(from[0])

            if (value != ProtocolPacketType.REQUEST) {
                throw IllegalStateException(ProtocolError.INVALID_DATA.name)
            }

            val data = from.drop(5).toByteArray()

            return CommandRequestPayload(data)
        }
    }

    override fun encode(): ByteArray {
        var packet = byteArrayOf(ProtocolPacketType.REQUEST.rawValue)

        packet += getTimestamp()
        packet += this.data

        return packet
    }
}

internal fun getTimestamp() =
    (System.currentTimeMillis() / 1000).toInt().run {
        byteArrayOf(
            this.toByte(),
            (this ushr 8).toByte(),
            (this ushr 16).toByte(),
            (this ushr 24).toByte()
        )
    }
