package io.twohire.bleintsdk.protocol

import android.content.*
import android.os.IBinder
import android.util.Log
import io.twohire.bleintsdk.bluetooth.BluetoothAction
import io.twohire.bleintsdk.bluetooth.BluetoothLeService
import io.twohire.bleintsdk.crypto.CryptoHelper
import io.twohire.bleintsdk.crypto.ECKeyPair
import io.twohire.bleintsdk.crypto.SealedBox
import io.twohire.bleintsdk.utils.toHex
import org.spongycastle.jce.interfaces.ECPrivateKey
import org.spongycastle.jce.interfaces.ECPublicKey
import kotlin.coroutines.Continuation
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

internal class ProtocolManager private constructor(
    private var keyPair: ECKeyPair,
    private val publicKey: ECPublicKey,
    private val delegate: ProtocolManagerDelegate
): ProtocolManagerDelegate by delegate {
    private val tag = "${ProtocolManager::class.simpleName}@${System.identityHashCode(this)}"

    private var bluetoothLeService: BluetoothLeService? = null
    private var bluetoothLeServiceConn: BluetoothLeServiceConnection? = null
    var writableState: WritableTLState? = null

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
                            this@ProtocolManager.delegate.didChangeState(state)
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
                        val decryptedData = decryptCommand(
                            this@ProtocolManager.readBuffer,
                            this@ProtocolManager.keyPair.privateKey,
                            this@ProtocolManager.publicKey
                        )

                        Log.d(tag, "Decrypted data ${decryptedData.toHex()}")

                        this@ProtocolManager.processCommandResponse(decryptedData)
                    } catch (error: Exception) {
                        Log.e(tag, "Error while stop reading")
                        this@ProtocolManager.writeContinuation?.resumeWithException(error)
                            .also { this@ProtocolManager.writeContinuation = null }
                    }
                }
            }
        }
    }

    private var connectionContinuation: Continuation<Boolean>? = null
    private var writeContinuation: Continuation<ProtocolResponse>? = null

    private var writeBuffer = arrayOf(ByteArray(0))
    private var readBuffer = ByteArray(0)

    private constructor(
        context: Context,
        keyPair: ECKeyPair,
        publicKey: ECPublicKey,
        callback: ProtocolManagerDelegate
    ) : this(keyPair, publicKey, callback) {

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

        context.registerReceiver(this.broadcastReceiver, IntentFilter().apply {
            addAction(BluetoothAction.ACTION_STATE_CHANGED)
            addAction(BluetoothAction.ACTION_CONNECT_COMPLETE)
            addAction(BluetoothAction.ACTION_CONNECT_ERROR)
            addAction(BluetoothAction.ACTION_WRITE_COMPLETE)
            addAction(BluetoothAction.ACTION_WRITE_ERROR)
            addAction(BluetoothAction.ACTION_READ_COMPLETE)
            addAction(BluetoothAction.ACTION_READ_DATA)
            addAction(BluetoothAction.ACTION_READ_ERROR)
        })
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

    suspend fun startSession(accessData: ByteArray) = suspendCoroutine<ProtocolResponse> { cont ->
        if (this@ProtocolManager.writeContinuation !== null) {
            cont.resumeWithException(IllegalStateException(ProtocolError.API_MISUSE.name))
        } else {
            try {
                this@ProtocolManager.writeContinuation = cont
                val personalPublicKey =
                    CryptoHelper.compactPublicKey(this@ProtocolManager.keyPair.publicKey)

                this@ProtocolManager.writeBuffer = arrayOf(
                    ProtocolConstants.START_SEQUENCE,
                    personalPublicKey + accessData,
                    ProtocolConstants.END_SEQUENCE
                )

                Log.d(
                    tag,
                    "Start session data ${
                        writeBuffer.map { it.contentToString() }.toTypedArray().contentToString()
                    }"
                )

                this@ProtocolManager.write()
            } catch (error: Exception) {
                cont.resumeWithException(error)
                this@ProtocolManager.writeContinuation = null
            }
        }
    }

    suspend fun sendCommand(payload: ByteArray) = suspendCoroutine<ProtocolResponse> { cont ->
        if (this@ProtocolManager.writeContinuation !== null) {
            cont.resumeWithException(IllegalStateException(ProtocolError.API_MISUSE.name))
        } else {
            try {
                this@ProtocolManager.writeContinuation = cont
                val commandPayload = createCommand(payload, keyPair.privateKey, publicKey)

                this@ProtocolManager.writeBuffer = arrayOf(
                    ProtocolConstants.START_SEQUENCE,
                    commandPayload,
                    ProtocolConstants.END_SEQUENCE
                )
                Log.d(
                    tag,
                    "Sending command data: ${
                        writeBuffer.map { it.contentToString() }.toTypedArray().contentToString()
                    }"
                )

                this@ProtocolManager.write()
            } catch (error: Exception) {
                cont.resumeWithException(error)
                this@ProtocolManager.writeContinuation = null
            }
        }
    }

    private fun processCommandResponse(payload: ByteArray) =
        this@ProtocolManager.writeContinuation?.let {
            val validity = payload[5]
            val additionalPayload = payload.drop(6).toByteArray()

            when (validity) {
                ProtocolConstants.ACK -> {
                    it.resumeWith(
                        Result.success(
                            ProtocolResponse(
                                true, additionalPayload
                            )
                        )
                    )
                }
                ProtocolConstants.NACK -> {
                    it.resumeWith(
                        Result.success(
                            ProtocolResponse(
                                false, additionalPayload
                            )
                        )
                    )
                }
                else -> {
                    it.resumeWithException(
                        IllegalStateException(ProtocolError.GENERIC.name)
                    )
                }
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

    fun setKeyPair(keyPair: ECKeyPair) {
        this.keyPair = keyPair
    }

    companion object {
        private val TAG = "${ProtocolManager::class.simpleName}"

        private var instance: ProtocolManager? = null

        fun getInstance(
            context: Context,
            keyPair: ECKeyPair,
            publicKey: ECPublicKey,
            callback: ProtocolManagerDelegate
        ): ProtocolManager {
            if (this.instance == null) {
                this.instance = ProtocolManager(context, keyPair, publicKey, callback)
            }

            return this.instance!!
        }

        private fun createCommand(
            payload: ByteArray,
            privateKey: ECPrivateKey,
            publicKey: ECPublicKey
        ): ByteArray {
            var dataToEncrypt = byteArrayOf(ProtocolMessageType.REQUEST)

            dataToEncrypt += getTimestamp()
            dataToEncrypt += payload

            Log.d(TAG, "Data to Encrypt: ${dataToEncrypt.contentToString()}")

            try {
                val sealedBox = CryptoHelper.encrypt(dataToEncrypt, privateKey, publicKey)

                return byteArrayOf(PROTOCOL_VERSION) + sealedBox.nonce + sealedBox.tag + sealedBox.data
            } catch (error: Exception) {
                Log.e(TAG, "Error while encrypting command data: ${error.message}")

                throw IllegalStateException(ProtocolError.CRYPTO.name)
            }
        }

        private fun decryptCommand(
            data: ByteArray,
            privateKey: ECPrivateKey,
            publicKey: ECPublicKey,
        ): ByteArray {
            val nonce = data.sliceArray(1 until 17)
            val tag = data.sliceArray(17 until 33)
            val encryptedPayload = data.drop(33).toByteArray()

            Log.d(TAG, "Buffer length ${data.size}")
            Log.d(TAG, "Nonce(${nonce.size}): ${nonce.contentToString()}")
            Log.d(TAG, "Tag(${tag.size}): ${tag.contentToString()}")
            Log.d(
                TAG,
                "EncryptedPayload(${encryptedPayload.size}): ${encryptedPayload.contentToString()}"
            )

            return CryptoHelper.decrypt(
                SealedBox(encryptedPayload, nonce, tag),
                privateKey,
                publicKey
            )
        }

        private fun getTimestamp() =
            (System.currentTimeMillis() / 1000).toInt().run {
                byteArrayOf(
                    this.toByte(),
                    (this ushr 8).toByte(),
                    (this ushr 16).toByte(),
                    (this ushr 24).toByte()
                )
            }
    }
}

internal interface ProtocolManagerDelegate {
    fun didChangeState(state: WritableTLState)
}