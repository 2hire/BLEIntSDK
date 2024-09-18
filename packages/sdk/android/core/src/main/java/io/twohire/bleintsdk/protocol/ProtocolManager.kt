package io.twohire.bleintsdk.protocol

import android.content.*
import android.os.IBinder
import android.util.Log
import androidx.core.content.ContextCompat
import io.twohire.bleintsdk.bluetooth.BluetoothAction
import io.twohire.bleintsdk.bluetooth.BluetoothError
import io.twohire.bleintsdk.bluetooth.BluetoothLeService
import io.twohire.bleintsdk.crypto.CryptoHelper
import io.twohire.bleintsdk.crypto.ECKeyPair
import io.twohire.bleintsdk.utils.toHex
import org.spongycastle.jce.interfaces.ECPublicKey
import kotlin.coroutines.Continuation
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

internal class ProtocolManager private constructor(
    private var keyPair: ECKeyPair,
    private var publicKey: ECPublicKey
) {
    private val tag = "${ProtocolManager::class.simpleName}@${System.identityHashCode(this)}"

    private var bluetoothLeService: BluetoothLeService? = null
    private var bluetoothLeServiceConn: BluetoothLeServiceConnection? = null
    var writableState: WritableTLState? = null

    fun setKeyPair(keyPair: ECKeyPair) {
        this.keyPair = keyPair
    }

    protected fun setPublicKey(keyPair: ECPublicKey) {
        this.publicKey = keyPair
    }

    private inner class BluetoothLeServiceConnection : ServiceConnection {
        override fun onServiceConnected(componentName: ComponentName?, binder: IBinder?) {
            Log.d(tag, "ServiceConnection: connected to $componentName")

            val service = (binder as BluetoothLeService.LocalBinder).service

            service.setDataMerger(ProtocolDataMerger())
            this@ProtocolManager.bluetoothLeService = service
        }

        override fun onServiceDisconnected(componentName: ComponentName?) {
            Log.w(tag, "ServiceConnection: disconnected from $componentName")

            this@ProtocolManager.bluetoothLeService = null
        }

        override fun onBindingDied(componentName: ComponentName?) {
            Log.w(tag, "ServiceConnection: onBindingDied $componentName")
        }

        override fun onNullBinding(componentName: ComponentName?) {
            Log.w(tag, "ServiceConnection: onNullBinding $componentName")
        }
    }

    private val broadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(p0: Context?, intent: Intent?) {
            Log.d(tag, "[Action]: BluetoothAction.${intent?.action}")

            when (intent?.action) {
                BluetoothAction.ACTION_STATE_CHANGED -> {
                    intent.getStringExtra(BluetoothAction.ACTION_EXTRA_DATA)?.let {
                        WritableTLState.fromName(it)?.let { state ->
                            Log.d(
                                tag,
                                "Did change state: ${this@ProtocolManager.writableState?.name} -> ${state.name}"
                            )
                            this@ProtocolManager.writableState = state
                        }
                    }
                }

                BluetoothAction.ACTION_CONNECT_COMPLETE -> {
                    Log.d(tag, "Writable connected")
                    this@ProtocolManager.connectionContinuation?.resume(true)
                        .also { this@ProtocolManager.connectionContinuation = null }
                }

                BluetoothAction.ACTION_CONNECT_ERROR -> {
                    Log.e(tag, "Connection error")

                    this@ProtocolManager.connectionContinuation?.resumeWithException(
                        IllegalStateException(
                            "${ProtocolError.WRITABLE.name}: (${
                                intent.getIntExtra(
                                    BluetoothAction.ACTION_EXTRA_DATA,
                                    -1
                                )
                            })"
                        )
                    )
                        .also {
                            this@ProtocolManager.connectionContinuation = null
                        }
                }

                BluetoothAction.ACTION_CONNECT_TIMEOUT -> {
                    Log.e(tag, "Connection timeout error")

                    this@ProtocolManager.connectionContinuation?.resumeWithException(
                        IllegalStateException(
                            BluetoothError.TIMEOUT_ERROR.name
                        )
                    )
                        .also {
                            this@ProtocolManager.connectionContinuation = null
                        }
                }

                BluetoothAction.ACTION_WRITE_COMPLETE -> {
                    try {
                        this@ProtocolManager.writeBuffer =
                            this@ProtocolManager.writeBuffer.drop(1).toTypedArray()
                        this@ProtocolManager.write()
                    } catch (error: Exception) {
                        Log.e(tag, "Error while writing ${error.message}")

                        this@ProtocolManager.writeContinuation?.resumeWithException(error)
                            .also { this@ProtocolManager.writeContinuation = null }
                    }
                }

                BluetoothAction.ACTION_WRITE_ERROR -> {
                    Log.e(tag, "Error while writing")

                    this@ProtocolManager.writeContinuation?.resumeWithException(
                        IllegalStateException(
                            "${ProtocolError.WRITABLE.name}: (${
                                intent.getIntExtra(
                                    BluetoothAction.ACTION_EXTRA_DATA,
                                    -1
                                )
                            })"
                        )
                    ).also { this@ProtocolManager.writeContinuation = null }
                }

                BluetoothAction.ACTION_READ_DATA -> {
                    val data = intent.getByteArrayExtra(BluetoothAction.ACTION_EXTRA_DATA)

                    if (data != null) {
                        Log.d(tag, "Incoming data: ${data.contentToString()}, closing")

                        try {
                            this@ProtocolManager.readBuffer = data
                            this@ProtocolManager.bluetoothLeService?.stopReading()
                        } catch (error: Exception) {
                            Log.e(tag, "Error while stop reading ${error.message}")

                            this@ProtocolManager.writeContinuation?.resumeWithException(
                                error
                            ).also { this@ProtocolManager.writeContinuation = null }
                        }
                    } else {
                        Log.e(tag, "Error while reading")

                        this@ProtocolManager.writeContinuation?.resumeWithException(
                            IllegalStateException(ProtocolError.WRITABLE.name)
                        ).also { this@ProtocolManager.writeContinuation = null }
                    }
                }

                BluetoothAction.ACTION_READ_ERROR -> {
                    Log.e(tag, "Error while reading")

                    this@ProtocolManager.writeContinuation?.resumeWithException(
                        IllegalStateException(
                            "${ProtocolError.WRITABLE.name}: (${
                                intent.getIntExtra(
                                    BluetoothAction.ACTION_EXTRA_DATA,
                                    -1
                                )
                            })"
                        )
                    )
                        .also { this@ProtocolManager.writeContinuation = null }
                }

                BluetoothAction.ACTION_READ_COMPLETE -> {
                    try {
                        Log.d(tag, "Stop read data: ${readBuffer.toHex()}")

                        val payload = arrayOf(
                            ProtocolFrame.SESSION_START.rawValue,
                            ProtocolFrame.COMMAND_START.rawValue
                        ).firstNotNullOf {
                            val firstMatch = readBuffer.slice(it.indices).toByteArray()
                            val secondMatch =
                                readBuffer.slice(it.indices.last + 1 until it.indices.last + 1 + it.size)
                                    .toByteArray()

                            if (secondMatch.contentEquals(it)) {
                                return@firstNotNullOf readBuffer.drop(it.size * 2).toByteArray()
                            } else if (firstMatch.contentEquals(it)) {
                                return@firstNotNullOf readBuffer.drop(it.size).toByteArray()
                            }

                            null
                        }.dropLast(4).toByteArray()

                        this@ProtocolManager.processCommandResponse(
                            EncryptedCommandPacket.create(
                                payload
                            )
                        )

                    } catch (error: NoSuchElementException) {
                        Log.e(tag, "Start frame not found")

                        this@ProtocolManager.writeContinuation?.resumeWithException(
                            IllegalStateException(ProtocolError.INVALID_DATA.name)
                        )
                            .also { this@ProtocolManager.writeContinuation = null }
                    } catch (error: Exception) {
                        Log.e(tag, "Error while stop reading (${error.message})")

                        this@ProtocolManager.writeContinuation?.resumeWithException(error)
                            .also { this@ProtocolManager.writeContinuation = null }
                    }
                }
            }
        }
    }

    private var connectionContinuation: Continuation<Boolean>? = null
    private var writeContinuation: Continuation<Result<ProtocolResponse>>? = null

    private var writeBuffer = arrayOf(ByteArray(0))
    private var readBuffer = ByteArray(0)

    private constructor(
        context: Context,
        keyPair: ECKeyPair,
        publicKey: ECPublicKey
    ) : this(keyPair, publicKey) {

        val connection = BluetoothLeServiceConnection()
        val status =
            context.bindService(
                Intent(
                    BluetoothAction.ACTION_BLE_SERVICE,
                    null,
                    context,
                    BluetoothLeService::class.java
                ), connection, Context.BIND_AUTO_CREATE
            )

        Log.d(tag, "ServiceStatus: $status")

        if (!status) {
            throw IllegalStateException(ProtocolError.INTERNAL.name)
        } else {
            this.bluetoothLeServiceConn = connection
        }

        ContextCompat.registerReceiver(
            context,
            this.broadcastReceiver,
            IntentFilter().apply {
                addAction(BluetoothAction.ACTION_STATE_CHANGED)
                addAction(BluetoothAction.ACTION_CONNECT_COMPLETE)
                addAction(BluetoothAction.ACTION_CONNECT_TIMEOUT)
                addAction(BluetoothAction.ACTION_CONNECT_ERROR)
                addAction(BluetoothAction.ACTION_WRITE_COMPLETE)
                addAction(BluetoothAction.ACTION_WRITE_ERROR)
                addAction(BluetoothAction.ACTION_READ_COMPLETE)
                addAction(BluetoothAction.ACTION_READ_DATA)
                addAction(BluetoothAction.ACTION_READ_ERROR)
            },
            ContextCompat.RECEIVER_EXPORTED
        )
    }

    suspend fun connect(id: String) = suspendCoroutine<Boolean> { cont ->
        if (this@ProtocolManager.connectionContinuation !== null) {
            cont.resumeWithException(IllegalStateException(ProtocolError.API_MISUSE.name))
        } else {
            try {
                this@ProtocolManager.connectionContinuation = cont
                this@ProtocolManager.bluetoothLeService?.connect(id)
            } catch (error: Exception) {
                cont.resumeWithException(error)
                this@ProtocolManager.connectionContinuation = null
            }
        }
    }

    suspend fun startSession(accessData: ByteArray) = withThrowingWriteContinuation { ->
        val personalPublicKey =
            CryptoHelper.compactPublicKey(this@ProtocolManager.keyPair.publicKey)

        this@ProtocolManager.writeBuffer = arrayOf(
            ProtocolFrame.SESSION_START.rawValue,
            personalPublicKey + accessData,
            ProtocolFrame.SESSION_END.rawValue,
        )

        Log.d(
            tag,
            "Start session data ${
                writeBuffer.map { it.contentToString() }.toTypedArray().contentToString()
            }"
        )

        this@ProtocolManager.write()
    }

    suspend fun sendCommand(payload: ByteArray) = withThrowingWriteContinuation {
        try {
            val commandPayload = CommandRequestPayload(payload).encode()

            val encryptedPacket = EncryptedCommandPacket.encrypt(
                commandPayload,
                PROTOCOL_VERSION,
                keyPair.privateKey,
                publicKey
            ).encode()

            this@ProtocolManager.writeBuffer = arrayOf(
                ProtocolFrame.COMMAND_START.rawValue,
                encryptedPacket,
                ProtocolFrame.COMMAND_END.rawValue
            )
        } catch (exception: Exception) {
            Log.e(tag, "Error while encrypting command data: ${exception.message}")
            throw IllegalStateException(ProtocolError.CRYPTO.name)
        }

        Log.d(
            tag,
            "Sending command data: ${
                writeBuffer.map { it.contentToString() }.toTypedArray().contentToString()
            }"
        )

        this@ProtocolManager.write()
    }

    private fun processCommandResponse(packet: EncryptedCommandPacket) =
        this@ProtocolManager.writeContinuation?.let {
            Log.d(
                tag,
                "Received encrypted command response: ${packet.data.toHex()}"
            )

            val decryptedData = packet.decrypt(
                this@ProtocolManager.keyPair.privateKey,
                this@ProtocolManager.publicKey
            )
            Log.d(
                tag,
                "Decrypted command data: ${decryptedData.toHex()}"
            )

            val commandPayload = CommandResponsePayload.create(decryptedData)

            if (commandPayload.commandIdentifier != CommandIdentifier.ERROR) {
                it.resume(
                    Result.success(
                        ProtocolResponse(
                            commandPayload.commandIdentifier == CommandIdentifier.ACK,
                            commandPayload.data
                        )
                    )
                )
            } else {
                val errorPayload = ErrorCommandPayload.create(commandPayload.data)
                it.resume(Result.failure(ProtocolErrorCodeException(errorPayload.errorCode)))
            }
        }.also {
            this@ProtocolManager.writeContinuation = null
        }

    private fun write() {
        try {
            val service =
                this.bluetoothLeService ?: throw IllegalStateException(ProtocolError.WRITABLE.name)

            if (this.writeBuffer.isEmpty()) {
                Log.d(tag, "Buffer is empty, starting read")
                service.startReading()
            } else if (this@ProtocolManager.writableState != WritableTLState.Connected) {
                Log.e(tag, "Writable is not in connected state")

                throw IllegalStateException(ProtocolError.WRITABLE.name)
            } else {
                service.write(writeBuffer.first())
            }
        } catch (error: Exception) {
            Log.e(tag, "Error while writing")

            this.writeContinuation?.resumeWithException(error).also {
                this.writeContinuation = null
            }
        }
    }

    private suspend fun withThrowingWriteContinuation(body: () -> Unit) =
        suspendCoroutine<Result<ProtocolResponse>> { cont ->
            if (this@ProtocolManager.writeContinuation !== null) {
                cont.resumeWithException(IllegalStateException(ProtocolError.API_MISUSE.name))
            }

            try {
                this@ProtocolManager.writeContinuation = cont

                body()
            } catch (exception: Exception) {
                cont.resumeWithException(exception)
                this@ProtocolManager.writeContinuation = null
            }
        }

    companion object {
        private val TAG = "${ProtocolManager::class.simpleName}"

        private var instance: ProtocolManager? = null

        fun getInstance(
            context: Context,
            keyPair: ECKeyPair,
            publicKey: ECPublicKey
        ): ProtocolManager {
            var instance = this.instance

            if (instance == null) {
                instance = ProtocolManager(context, keyPair, publicKey)
                this.instance = instance
            } else {
                instance.setKeyPair(keyPair)
                instance.setPublicKey(publicKey)
            }

            return instance
        }
    }
}

internal class ProtocolErrorCodeException(val errorCode: ProtocolErrorCode) : Throwable()