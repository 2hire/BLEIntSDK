package io.twohire.bleintsdk.utils

internal fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }