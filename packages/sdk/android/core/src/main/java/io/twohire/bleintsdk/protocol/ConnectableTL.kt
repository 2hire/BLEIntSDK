package io.twohire.bleintsdk.protocol

internal interface ConnectableTL {
    @Throws
    fun connect(address: String)
}