package io.twohire.bleintsdk.client

import android.content.Context
import android.util.Base64
import android.util.Log
import io.twohire.bleintsdk.crypto.CryptoHelper
import io.twohire.bleintsdk.crypto.KeyStore
import io.twohire.bleintsdk.protocol.*
import io.twohire.bleintsdk.protocol.ProtocolErrorCode
import io.twohire.bleintsdk.protocol.ProtocolErrorCodeException
import io.twohire.bleintsdk.protocol.ProtocolManager
import io.twohire.bleintsdk.protocol.WritableTLState
import io.twohire.bleintsdk.utils.BLEIntError
import io.twohire.bleintsdk.utils.BLEIntSDKException
import io.twohire.bleintsdk.utils.ErrorDescription

typealias CommandResponse = ProtocolResponse

class Client {
    private val tag = "${Client::class.simpleName}@${System.identityHashCode(this)}"

    private var config: SessionConfig? = null
    private var manager: ProtocolManager? = null

    private var identifier: String? = null

    private var context: Context? = null

    fun sessionSetup(context: Context, config: SessionConfig) {
        try {
            val keys = KeyStore.getOrGeneratePrivateKey(context)
            val vehiclePubKey = CryptoHelper.wrapPublicKey(config.publicKey.fromBase64ToByteArray())

            this.context = context
            this.config = config

            Log.d(tag, "Creating ProtocolManager $config")

            this.manager =
                ProtocolManager.getInstance(
                    context,
                    keys,
                    vehiclePubKey
                )
        } catch (error: Exception) {
            this.logAndMapError(error)
        }
    }

    suspend fun connectToVehicle(macAddress: String): CommandResponse? =
        this.catchInternalError {
            val manager = this.manager
            val sessionData = this.config
            val context = this.context

            if (manager == null) {
                Log.e(tag, "Error while connecting to vehicle, manager is null")
                throw IllegalStateException(ClientError.INVALID_STATE.name)
            }

            if (sessionData == null) {
                Log.e(tag, "Error while connecting to vehicle, sessionData is null")
                throw IllegalStateException(ClientError.INVALID_STATE.name)
            }

            if (context == null) {
                Log.e(tag, "Error while connecting to vehicle, context is null")
                throw IllegalStateException(ClientError.INVALID_STATE.name)
            }

            this.identifier = macAddress
            this.connect()

            try {
                val keyPair = KeyStore.getOrGeneratePrivateKey(context)
                manager.setKeyPair(keyPair)

                try {
                    return@catchInternalError manager.startSession(sessionData.accessToken.fromBase64ToByteArray()).getOrThrow()
                } catch (error: ProtocolErrorCodeException) {
                    if (error.errorCode == ProtocolErrorCode.ALREADY_VALIDATED) {
                        Log.i(tag, "Session is still valid")

                        return@catchInternalError null
                    }
                    Log.e(tag, "Received protocol error code ${error.errorCode.rawValue}")

                    throw IllegalStateException(ClientError.INVALID_SESSION.name)
                }
            } catch (error: Exception) {
                Log.e(tag, "Error while creating session, removing PrivateKey")
                KeyStore.deletePrivatKey(context)

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

            try {
                return@catchInternalError manager.sendCommand(command).getOrThrow()
            } catch (error: ProtocolErrorCodeException) {
                Log.e(tag, "Received protocol error code ${error.errorCode.rawValue}")

                throw IllegalStateException(ClientError.INVALID_COMMAND.name)
            }
        }

    suspend fun endSession(): CommandResponse {
        val data = this.sendCommand(CommandType.EndSession)
        val context = this.context

        if (context != null) {
           try {
               Log.d(tag, "Session is closed, deleting PrivateKey")
               KeyStore.deletePrivatKey(context)
           } catch (error: Exception) {
               Log.e(tag, "Error while deleting PrivateKey (${error.message})")
           }
       } else {
           Log.e(tag, "Error context is null")
       }

        this.config = null
        this.manager = null
        this.identifier = null
        this.context = null

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
}

internal fun String.fromBase64ToByteArray(): ByteArray = try {
    Base64.decode(this, Base64.DEFAULT)
} catch (e: Exception) {
    throw IllegalStateException(ClientError.INVALID_DATA.name)
}