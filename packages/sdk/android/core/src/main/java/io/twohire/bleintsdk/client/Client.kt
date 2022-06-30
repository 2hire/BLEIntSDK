package io.twohire.bleintsdk.client

import android.content.Context
import android.util.Base64
import android.util.Log
import io.twohire.bleintsdk.crypto.CryptoHelper
import io.twohire.bleintsdk.crypto.KeyStore
import io.twohire.bleintsdk.protocol.ProtocolManager
import io.twohire.bleintsdk.protocol.ProtocolResponse
import io.twohire.bleintsdk.protocol.WritableTLState

typealias CommandResponse = ProtocolResponse

class Client {
    private val tag = "${Client::class.simpleName}@${System.identityHashCode(this)}"

    private var config: SessionConfig? = null

    private var manager: ProtocolManager? = null

    private var identifier: String? = null

    fun sessionSetup(context: Context, config: SessionConfig) {
        val keys = KeyStore.getOrGeneratePrivateKey(context)
        val vehiclePubKey = CryptoHelper.wrapPublicKey(config.publicKey.fromBase64ToByteArray())

        this.config = config

        Log.d(tag, "Creating ProtocolManager")

        this.manager = ProtocolManager.getInstance(context, keys, vehiclePubKey)
    }

    suspend fun connectToVehicle(macAddress: String, context: Context): CommandResponse {
        val manager = this.manager
        val sessionData = this.config
        val command = sessionData?.commands?.get(CommandType.Noop)?.fromBase64ToByteArray()

        if (manager == null || sessionData == null || command == null) {
            Log.e(tag, "Error while connecting to vehicle")
            throw IllegalStateException("GenericError")
        }

        this.identifier = macAddress
        this.connect()

        Log.d(tag, "Sending Noop command to retrieve connection status")

        return try {
            manager.sendCommand(command)
        } catch (error: Exception) {
            Log.d(tag, "Noop failed, reconnecting")

            manager.connect(macAddress)

            Log.d(tag, "Generating a new KeyPair")
            val keyPair = KeyStore.generateAndSaveKeyPair(context)
            manager.setKeyPair(keyPair)

            Log.d(tag, "Starting a new session")

            manager.startSession(sessionData.accessToken.fromBase64ToByteArray())
        }
    }

    suspend fun sendCommand(commandType: CommandType): CommandResponse {
        val manager = this.manager
        val sessionData = this.config
        val command = sessionData?.commands?.get(commandType)?.fromBase64ToByteArray()

        if (manager == null || sessionData == null || command == null) {
            Log.e(tag, "Error while sending command")
            throw IllegalStateException("GenericError")
        }

        if (manager.writableState != WritableTLState.Connected) {
            Log.d(tag, "Connecting to vehicle")
            this.connect()
        } else {
            Log.d(tag, "Vehicle is already connected, skipping")
        }

        Log.d(tag, "Sending command")

        return manager.sendCommand(command)
    }

    suspend fun endSession(): CommandResponse {
        val data = this.sendCommand(CommandType.EndSession)

        this.config = null
        this.manager = null
        this.identifier = null

        return data
    }

    private suspend fun connect() {
        val manager = this.manager
        val identifier = this.identifier

        if (manager == null || identifier == null) {
            Log.e(tag, "Error while connecting to vehicle")
            throw IllegalStateException("GenericError")
        }

        Log.d(tag, "ProtocolManager status: ${manager.writableState?.name}")

        if (manager.writableState != WritableTLState.Connected) {
            Log.d(tag, "Connecting")

            manager.connect(identifier)
        }
    }
}

internal fun String.fromBase64ToByteArray(): ByteArray = Base64.decode(this, Base64.DEFAULT)