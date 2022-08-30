package io.twohire.bleintsdk.protocol

import android.util.Log
import io.twohire.bleintsdk.utils.toHex
import no.nordicsemi.android.ble.data.DataMerger
import no.nordicsemi.android.ble.data.DataStream

internal class ProtocolDataMerger : DataMerger {
    private val tag = "${ProtocolDataMerger::class.simpleName}@${System.identityHashCode(this)}"

    override fun merge(output: DataStream, lastPacket: ByteArray?, index: Int): Boolean {
        if (lastPacket != null) {
            Log.d(tag, "Received data ($index): ${lastPacket?.toHex()}")
            output.write(lastPacket)

            if (lastPacket.contentEquals(ProtocolFrame.SESSION_START.rawValue) || lastPacket.contentEquals(ProtocolFrame.COMMAND_START.rawValue)) {
                Log.d(tag,"Start sequence")

                return false
            } else if (lastPacket.contentEquals(ProtocolFrame.SESSION_END.rawValue) || lastPacket.contentEquals(ProtocolFrame.COMMAND_END.rawValue)) {
                Log.d(tag, "End sequence")
            } else {
                Log.d(tag, "Payload data")

                return false
            }
        } else {
            Log.e(tag, "Error while reading, data is null")
        }

        return true
    }
}