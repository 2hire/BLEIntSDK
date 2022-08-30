package io.twohire.bleintsdk.utils

internal fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }
internal fun String.toByteArray(): ByteArray = chunked(2).map { it.toInt(16).toByte() }.toByteArray()