package io.twohire.bleintsdk.protocol

import android.util.Log
import no.nordicsemi.android.ble.data.DataMerger
import no.nordicsemi.android.ble.data.DataStream

internal class ProtocolDataMerger : DataMerger {
    private val tag = "${ProtocolDataMerger::class.simpleName}@${System.identityHashCode(this)}"

    override fun merge(output: DataStream, lastPacket: ByteArray?, index: Int): Boolean {
        if (lastPacket != null) {
            if (lastPacket.contentEquals(ProtocolConstants.START_SEQUENCE)) {
                Log.d(
                    tag,
                    "Start sequence: ${lastPacket.contentToString()}, skipping"
                )

                return false
            } else if (lastPacket.contentEquals(ProtocolConstants.END_SEQUENCE)) {
                Log.d(tag, "End sequence: ${lastPacket.contentToString()}, no more data is needed")
            } else {
                Log.d(tag, "Payload data ${lastPacket.contentToString()}")

                output.write(lastPacket)

                return false
            }
        } else {
            Log.e(tag, "Error while reading, data is null")
        }

        return true
    }
}