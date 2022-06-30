package io.twohire.bleintsdk.protocol

internal interface WritableTL : ConnectableTL {
    @Throws
    fun write(data: ByteArray)

    @Throws
    fun startReading()

    @Throws
    fun stopReading()
}