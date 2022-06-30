package io.twohire.bleintsdk.crypto

internal data class SealedBox(val data: ByteArray, val nonce: ByteArray, val tag: ByteArray)
