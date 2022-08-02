package io.twohire.bleintsdk.client

import android.content.Context
import android.util.Base64
import android.util.Log
import io.twohire.bleintsdk.crypto.CryptoHelper
import io.twohire.bleintsdk.crypto.KeyStore
import io.twohire.bleintsdk.protocol.ProtocolManager
import io.twohire.bleintsdk.protocol.ProtocolManagerDelegate
import io.twohire.bleintsdk.protocol.ProtocolResponse
import io.twohire.bleintsdk.protocol.WritableTLState
import io.twohire.bleintsdk.utils.BLEIntError
import io.twohire.bleintsdk.utils.BLEIntSDKException
import io.twohire.bleintsdk.utils.ErrorDescription

typealias CommandResponse = ProtocolResponse

class Client {
    private val tag = "${Client::class.simpleName}@${System.identityHashCode(this)}"

    private var config: SessionConfig? = null

    private var manager: ProtocolManager? = null
    private var writableStateHistory: List<WritableTLState> = mutableListOf()

    private var identifier: String? = null

    fun sessionSetup(context: Context, config: SessionConfig) {
        try {
            val keys = KeyStore.getOrGeneratePrivateKey(context)
            val vehiclePubKey = CryptoHelper.wrapPublicKey(config.publicKey.fromBase64ToByteArray())

            this.config = config

            Log.d(tag, "Creating ProtocolManager")

            this.manager =
                ProtocolManager.getInstance(
                    context,
                    keys,
                    vehiclePubKey,
                    ManagerDelegate()
                )
        } catch (error: Exception) {
            this.logAndMapError(error)
        }
    }

    suspend fun connectToVehicle(macAddress: String, context: Context): CommandResponse =
        this.catchInternalError {
            val manager = this.manager
            val sessionData = this.config
            val command = sessionData?.commands?.get(CommandType.Noop)?.fromBase64ToByteArray()

            if (manager == null) {
                Log.e(tag, "Error while connecting to vehicle, manager is null")
                throw IllegalStateException(ClientError.INVALID_STATE.name)
            }

            if (sessionData == null) {
                Log.e(tag, "Error while connecting to vehicle, sessionData is null")
                throw IllegalStateException(ClientError.INVALID_STATE.name)
            }

            if (command == null) {
                Log.e(tag, "Error while connecting to vehicle, command is null")
                throw IllegalStateException(ClientError.INVALID_STATE.name)
            }

            this.identifier = macAddress
            this.connect()

            var invalidNoopSession = false

            Log.d(tag, "Sending Noop command to retrieve connection status")

            try {
                try {
                    manager.sendCommand(command)
                } catch (error: Exception) {
                    Log.d(tag, "Noop failed, reconnecting")

                    if (checkInvalidSession(writableStateHistory)) {
                        invalidNoopSession = true
                        Log.d(tag, "Noop failed for an INVALID_SESSION")
                    }

                    manager.connect(macAddress)

                    Log.d(tag, "Generating a new KeyPair")
                    val keyPair = KeyStore.generateAndSaveKeyPair(context)
                    manager.setKeyPair(keyPair)

                    Log.d(tag, "Starting a new session")

                    manager.startSession(sessionData.accessToken.fromBase64ToByteArray())
                }
            } catch (error: Exception) {
                if (invalidNoopSession && checkInvalidSession(writableStateHistory)) {
                    Log.d(
                        tag,
                        "ConnectToVehicle failed with two consecutive INVALID_SESSION errors"
                    )
                    throw IllegalStateException(ClientError.INVALID_SESSION.name)
                }

                throw error
            }
        }

    suspend fun sendCommand(commandType: CommandType): CommandResponse =
        this.catchInternalError {
            val manager = this.manager
            val sessionData = this.config
            val command = sessionData?.commands?.get(commandType)?.fromBase64ToByteArray()

            if (manager == null) {
                Log.e(tag, "Error while sending command, manager is null")
                throw IllegalStateException(ClientError.INVALID_STATE.name)
            }

            if (sessionData == null) {
                Log.e(tag, "Error while sending command, sessionData is null")
                throw IllegalStateException(ClientError.INVALID_STATE.name)
            }

            if (command == null) {
                Log.e(tag, "Error while sending command, command is null")
                throw IllegalStateException(ClientError.INVALID_STATE.name)
            }

            if (manager.writableState != WritableTLState.Connected) {
                Log.d(tag, "Connecting to vehicle")
                this.connect()
            } else {
                Log.d(tag, "Vehicle is already connected, skipping")
            }

            Log.d(tag, "Sending command")

            manager.sendCommand(command)
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

        if (manager == null) {
            Log.e(tag, "Error while sending command, manager is null")
            throw IllegalStateException(ClientError.INVALID_STATE.name)
        }

        if (identifier == null) {
            Log.e(tag, "Error while sending command, identifier is null")
            throw IllegalStateException(ClientError.INVALID_STATE.name)
        }

        Log.d(tag, "ProtocolManager status: ${manager.writableState?.name}")

        if (manager.writableState != WritableTLState.Connected) {
            Log.d(tag, "Connecting")

            manager.connect(identifier)
        }
    }

    private suspend fun <T> catchInternalError(throwingCallback: suspend () -> T): T {
        return try {
            throwingCallback()
        } catch (error: Exception) {
            throw BLEIntSDKException(this.logAndMapError(error))
        }
    }

    private fun logAndMapError(internalError: Exception) =
        BLEIntError.fromError(internalError.message)
            .also {
                Log.e(
                    tag,
                    "[${it.code}]: ${if (internalError is ErrorDescription) internalError.description else internalError.message}"
                )
            }

    private inner class ManagerDelegate : ProtocolManagerDelegate {
        override fun didChangeState(state: WritableTLState) {
            this@Client.writableStateHistory += state
        }
    }
}

internal fun String.fromBase64ToByteArray(): ByteArray = try {
    Base64.decode(this, Base64.DEFAULT)
} catch (e: Exception) {
    throw IllegalStateException(ClientError.INVALID_DATA.name)
}