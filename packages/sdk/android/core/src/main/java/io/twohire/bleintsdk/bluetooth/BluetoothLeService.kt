package io.twohire.bleintsdk.bluetooth

import android.annotation.SuppressLint
import android.app.Service
import android.bluetooth.*
import android.content.Context
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import android.os.ParcelUuid
import android.util.Log
import io.twohire.bleintsdk.protocol.WritableTL
import io.twohire.bleintsdk.protocol.WritableTLState
import io.twohire.bleintsdk.utils.toHex
import no.nordicsemi.android.ble.BleManager
import no.nordicsemi.android.ble.BuildConfig
import no.nordicsemi.android.ble.data.DataMerger
import no.nordicsemi.android.ble.data.DefaultMtuSplitter
import no.nordicsemi.android.ble.observer.ConnectionObserver
import no.nordicsemi.android.support.v18.scanner.*
import java.util.*

@SuppressLint("MissingPermission")
internal class BluetoothLeService : Service(), WritableTL {
    private val tag = BluetoothLeService::class.simpleName

    private var internalState: WritableTLState = WritableTLState.Unknown
    private var state: WritableTLState
        get() = internalState
        set(value) {
            val oldValue = this.internalState
            this.internalState = value

            if (oldValue != value) {
                Log.d(tag, "Status changed $oldValue -> $value")
                this.senderWritableTLState = oldValue

                broadcastUpdate(
                    Intent(BluetoothAction.ACTION_STATE_CHANGED).putExtra(
                        BluetoothAction.ACTION_EXTRA_DATA,
                        value.name
                    )
                )
            }
        }
    private var senderWritableTLState: WritableTLState = WritableTLState.Unknown

    //region DataMerger
    private var dataMerger: DataMerger? = null

    internal fun setDataMerger(merger: DataMerger) = run { this.dataMerger = merger }
    //endregion

    private var manager: ClientManager? = null
    private var scanCallback: ScanCallback? = null
    private var scanner: BluetoothLeScannerCompat? = null
    private var device: BluetoothDevice? = null

    private var timer: Timer? = null

    //region Writing
    @Throws
    override fun write(data: ByteArray) {
        if (this.state !== WritableTLState.Connected) {
            Log.e(tag, "Bluetooth is not connected")
            throw IllegalStateException(BluetoothError.NOT_CONNECTED.name)
        }

        val manager =
            this.manager ?: throw IllegalStateException(BluetoothError.PERIPHERAL_NOT_FOUND.name)

        manager.apply {
            this.writeRequest(data)
                .split(DefaultMtuSplitter()) { _, chunk, _ ->
                    Log.d(tag, "Wrote Data: [${chunk?.toHex()}]")
                }
                .before {
                    this@BluetoothLeService.state = WritableTLState.Writing

                    Log.d(tag, "Beginning write")
                }
                .fail { _, reason ->
                    Log.e(tag, "Error while writing")

                    broadcastUpdate(
                        Intent(BluetoothAction.ACTION_WRITE_ERROR).putExtra(
                            BluetoothAction.ACTION_EXTRA_DATA,
                            reason
                        )
                    )
                }
                .done {
                    Log.d(
                        tag,
                        "Write buffer empty, current status ${this@BluetoothLeService.state}, resetting to previous status $senderWritableTLState"
                    )

                    this@BluetoothLeService.state =
                        this@BluetoothLeService.senderWritableTLState

                    broadcastUpdate(
                        Intent(BluetoothAction.ACTION_WRITE_COMPLETE)
                    )
                }.enqueue()
        }
    }
    //endregion

    //region Reading
    @Throws
    override fun startReading() {
        if (this.state != WritableTLState.Connected) {
            Log.e(tag, "Bluetooth is not in Connected state: $state")

            throw IllegalStateException(BluetoothError.NOT_CONNECTED.name)
        }

        val manager =
            this.manager ?: throw IllegalStateException(BluetoothError.PERIPHERAL_NOT_FOUND.name)
        val dataMerger = this.dataMerger ?: throw IllegalStateException(BluetoothError.GENERIC.name)

        manager.apply {
            var startingReadCharacteristicValue: ByteArray? = null

            this.getRequestQueue()
                .add(
                    this.enableIndicationsRequest()
                        .before {
                            Log.d(tag, "Starting enable indications request")
                            this@BluetoothLeService.state = WritableTLState.Reading
                        }
                        .fail { _, status ->
                            this.waitUntilDisconnection {
                                Log.e(
                                    tag,
                                    "Found error while reading new indications state $status"
                                )

                                this@BluetoothLeService.state = WritableTLState.Errored

                                broadcastUpdate(
                                    Intent(BluetoothAction.ACTION_READ_ERROR).putExtra(
                                        BluetoothAction.ACTION_EXTRA_DATA,
                                        status
                                    )
                                )
                            }
                        }
                        .done {
                            Log.d(tag, "Done writing enable indications request")
                        })
                .add(
                    this.readIndicationRequest()
                        .before { Log.d(tag, "Starting read request")

                            this.getReadCharacteristicValue()?.let {
                                Log.d(tag, "Read characteristic value: ${it.toHex()}")
                                startingReadCharacteristicValue = it
                            }
                        }
                        .merge(
                            dataMerger
                        ) { _, chunk, _ -> Log.d(tag, "received chunk [${chunk?.toHex()}]") }
                        .with { _, data ->
                            Log.d(tag, "Received data ${data.value?.toHex()}")

                            if (data.size() == 0) {
                                Log.d(tag, "Received data is empty!")
                            }

                            val value = data.value?.let {
                                startingReadCharacteristicValue?.let { bytes ->
                                    return@let bytes + it
                                } ?: it
                            }

                            broadcastUpdate(
                                Intent(BluetoothAction.ACTION_READ_DATA).putExtra(
                                    BluetoothAction.ACTION_EXTRA_DATA,
                                    value
                                )
                            )
                        }.fail { _, status ->
                            this.waitUntilDisconnection {
                                Log.e(
                                    tag,
                                    "Found error while reading state: $status"
                                )
                                this@BluetoothLeService.state = WritableTLState.Errored

                                broadcastUpdate(
                                    Intent(BluetoothAction.ACTION_READ_ERROR).putExtra(
                                        BluetoothAction.ACTION_EXTRA_DATA,
                                        status
                                    )
                                )
                            }
                        }
                        .timeout(BluetoothConstants.READ_TIMEOUT)
                        .done {
                            Log.d(tag, "Done reading value")
                        })
                .enqueue()
        }
    }

    @Throws
    override fun stopReading() {
        if (this.state != WritableTLState.Reading) {
            Log.e(tag, "Bluetooth is not in Reading state: $state")
            throw IllegalStateException(BluetoothError.NOT_READING.name)
        }

        val manager =
            this.manager ?: throw IllegalStateException(BluetoothError.PERIPHERAL_NOT_FOUND.name)

        manager.apply {
            this.disableIndicationsRequest()
                .before { Log.d(tag, "starting disable indications request") }
                .fail { _, status ->
                    Log.e(tag, "Found error while disabling indications")

                    this@BluetoothLeService.stopScan()
                    this@BluetoothLeService.state = WritableTLState.Errored

                    broadcastUpdate(
                        Intent(BluetoothAction.ACTION_READ_ERROR).putExtra(
                            BluetoothAction.ACTION_EXTRA_DATA,
                            status
                        )
                    )
                }.done {
                    Log.d(tag, "Done writing disable indications request")

                    if (this@BluetoothLeService.state != WritableTLState.Errored) {
                        this@BluetoothLeService.state =
                            this@BluetoothLeService.senderWritableTLState

                        broadcastUpdate(
                            Intent(BluetoothAction.ACTION_READ_COMPLETE)
                        )
                    }
                }.enqueue()
        }
    }

    @Throws
    override fun connect(address: String) {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

        if (bluetoothManager.adapter.isEnabled) {
            val device = this.device
            val parsedAddress = checkAndParseBluetoothAddress(address)

            if (device !== null && parsedAddress == device.address) {
                this.connectToDevice(device)
            } else {
                val filters = getScanFilters(parsedAddress)

                this.startScan(filters)
            }
        } else {
            throw IllegalStateException(BluetoothError.ADAPTER_NOT_ENABLED.name)
        }
    }

    private fun close() {
        Log.d(tag, "Closing")

        this.device = null
        this.manager?.close()
        this.state = WritableTLState.Unknown
    }

    private fun connectToDevice(device: BluetoothDevice) {
        this.state = WritableTLState.Created

        val manager = ClientManager()
        manager
            .connect(device)
            .retry(3)
            .useAutoConnect(false)
            .timeout(BluetoothConstants.CONNECTION_TIMEOUT)
            .fail { _, status ->
                Log.e(tag, "Found error while connecting $status")

                this.device = null
                this.state = WritableTLState.Errored

                broadcastUpdate(
                    Intent(BluetoothAction.ACTION_CONNECT_ERROR).putExtra(
                        BluetoothAction.ACTION_EXTRA_DATA,
                        status
                    )
                )
            }
            .done {
                this.state = WritableTLState.Connected
                this.manager = manager
                this.device = device

                manager.connectionObserver = ClientConnectionObserver()
                broadcastUpdate(Intent(BluetoothAction.ACTION_CONNECT_COMPLETE))
            }
            .then { this.scanCallback?.let { callback -> this.scanner?.stopScan(callback) } }
            .enqueue()
    }

    private fun startScan(filters: List<ScanFilter>) {
        val scanner = BluetoothLeScannerCompat.getScanner()
        val settings = ScanSettings.Builder()
            .setLegacy(false)
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setReportDelay(5_000)
            .setUseHardwareBatchingIfSupported(false)
            .build()

        val callback = ClientScanCallback().apply { scanCallback = this }

        val task = ScanTimerTask()

        this.timer = Timer().also {
            it.schedule(task, BluetoothConstants.SCAN_TIMEOUT)
            Log.d(tag, "Scheduled scan timer $task")
        }

        this.scanner = scanner
        scanner.startScan(filters, settings, callback)
    }

    private fun stopScan() {
        this.timer?.cancel().let {
            this.timer = null
            Log.d(tag, "Invalidated scan timer $it")
        }
        this.scanCallback?.let { this.scanner?.stopScan(it) }
    }

    private inner class ScanTimerTask : TimerTask() {
        override fun run() {
            Log.d(tag, "Scan timer $this")
            timer = null

            this@BluetoothLeService.stopScan()
            this@BluetoothLeService.state = WritableTLState.Unknown

            broadcastUpdate(
                Intent(BluetoothAction.ACTION_CONNECT_TIMEOUT).putExtra(
                    BluetoothAction.ACTION_EXTRA_DATA,
                    BluetoothError.TIMEOUT_ERROR.ordinal
                )
            )
        }
    }

    private inner class ClientScanCallback : ScanCallback() {
        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            Log.d(
                tag,
                "Scan results: ${
                    results.map { "[device=${it.device.address}, connectable=${it.isConnectable}]" }
                        .toTypedArray().contentToString()
                }"
            )

            if (results.size > 0 && results[0].isConnectable) {
                this@BluetoothLeService.stopScan()
                this@BluetoothLeService.connectToDevice(results[0].device)
            }
        }

        override fun onScanFailed(errorCode: Int) {
            this@BluetoothLeService.stopScan()

            this@BluetoothLeService.state = WritableTLState.Unknown

            broadcastUpdate(
                Intent(BluetoothAction.ACTION_CONNECT_ERROR).putExtra(
                    BluetoothAction.ACTION_EXTRA_DATA,
                    errorCode
                )
            )
        }
    }

    private inner class ClientConnectionObserver : ConnectionObserver {
        override fun onDeviceConnecting(device: BluetoothDevice) {}

        override fun onDeviceConnected(device: BluetoothDevice) {}

        override fun onDeviceFailedToConnect(device: BluetoothDevice, reason: Int) {}

        override fun onDeviceReady(device: BluetoothDevice) {}

        override fun onDeviceDisconnecting(device: BluetoothDevice) {}

        override fun onDeviceDisconnected(device: BluetoothDevice, reason: Int) {
            Log.d(tag, "Device disconnected")

            this@BluetoothLeService.state = WritableTLState.Unknown
        }
    }

    private inner class ClientManager : BleManager(this@BluetoothLeService) {
        private var readCharacteristic: BluetoothGattCharacteristic? = null
        private var writeCharacteristic: BluetoothGattCharacteristic? = null

        fun writeRequest(data: ByteArray) = this.writeCharacteristic(
            writeCharacteristic,
            data,
            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        )

        fun readIndicationRequest() = this.waitForIndication(readCharacteristic)

        fun enableIndicationsRequest() =
            this.enableIndications(readCharacteristic)

        fun disableIndicationsRequest() =
            this.disableIndications(readCharacteristic)

        fun waitUntilDisconnection(callback: (() -> Unit)) {
            if (!this.isConnected) {
                callback()
            } else {
                this.waitIf { !this.isConnected }.timeout(BluetoothConstants.DISCONNECTION_TIMEOUT)
                    .done { callback() }.enqueue()
            }
        }

        fun getReadCharacteristicValue() = this.readCharacteristic?.value

        fun getRequestQueue() = this.beginAtomicRequestQueue()

        override fun getGattCallback() = GattCallback()

        override fun getMinLogPriority() = Log.DEBUG

        override fun getMtu() = BluetoothConstants.MTU

        override fun shouldClearCacheWhenDisconnected() = true

        override fun log(priority: Int, message: String) {
            if (BuildConfig.DEBUG || priority == Log.ERROR) {
                Log.println(priority, tag, message)
            }
        }

        private inner class GattCallback : BleManagerGattCallback() {
            override fun isRequiredServiceSupported(gatt: BluetoothGatt): Boolean {
                val service = gatt.getService(UUID.fromString(BluetoothConstants.GATT_SERVICE))
                readCharacteristic =
                    service?.getCharacteristic(UUID.fromString(BluetoothConstants.READ_CHARACTERISTIC))
                writeCharacteristic =
                    service?.getCharacteristic(UUID.fromString(BluetoothConstants.WRITE_CHARACTERISTIC))

                return readCharacteristic != null && writeCharacteristic != null
            }

            override fun onServicesInvalidated() {
                writeCharacteristic = null
                readCharacteristic = null
            }

            override fun onDeviceReady() {
                Log.d(tag, "Device is ready")
            }
        }
    }

    inner class LocalBinder : Binder() {
        val service: BluetoothLeService = this@BluetoothLeService
    }

    override fun onBind(intent: Intent?): IBinder? =
        when (intent?.action) {
            BluetoothAction.ACTION_BLE_SERVICE -> {
                Log.d(tag, "Service bound")
                LocalBinder()
            }
            else -> null
        }

    override fun onUnbind(intent: Intent?): Boolean =
        when (intent?.action) {
            BluetoothAction.ACTION_BLE_SERVICE -> {
                Log.d(tag, "Unbind Service")
                close()

                true
            }
            else -> false
        }

    private fun broadcastUpdate(intent: Intent) {
        sendBroadcast(intent)
    }

    companion object {
        private fun getScanFilters(address: String): List<ScanFilter> =
            arrayListOf(
                ScanFilter
                    .Builder()
                    .setDeviceAddress(address)
                    .setServiceUuid(ParcelUuid.fromString(BluetoothConstants.GATT_SERVICE))
                    .build()
            )

        private fun checkAndParseBluetoothAddress(address: String): String {
            if (BluetoothAdapter.checkBluetoothAddress(address)) {
                return address
            }

            if (address.length == 12) {
                var parsedAddress = ""

                for (index in address.indices) {
                    if (address[index] == ':') {
                        // break loop if we found an existing ':'
                        break
                    }

                    if (index != 0 && index % 2 == 0) {
                        parsedAddress += ":"
                    }

                    parsedAddress += address[index]
                }

                // mac address should be an hex string
                parsedAddress = parsedAddress.uppercase(Locale.getDefault())

                if (BluetoothAdapter.checkBluetoothAddress(parsedAddress)) {
                    return parsedAddress
                }
            }

            throw IllegalArgumentException("$address is not a valid Bluetooth address")
        }
    }
}
