package io.twohire.bleintsdk.bluetooth

internal object BluetoothConstants {
    const val GATT_SERVICE = "88283254-B0DB-7992-BB47-45A75DF6C2F1"
    const val READ_CHARACTERISTIC = "92B867E8-2AA3-5D9E-C94D-F06338E6B4F8"
    const val WRITE_CHARACTERISTIC = "92B867E8-2AA3-5D9E-C94D-F06338E6B4E8"

    const val SCAN_TIMEOUT = 35_000L
    const val CONNECTION_TIMEOUT = 15_000L
    const val DISCONNECTION_TIMEOUT = 7_500L
    const val WRITE_RESPONSE_TIMEOUT = 20_000L
    const val READ_TIMEOUT = 60_000L
    const val MTU = 23
}

internal object BluetoothAction {
    const val ACTION_BLE_SERVICE = "io.twohire.bleintsdk.bluetooth.ACTION_BLE_SERVICE"

    const val ACTION_STATE_CHANGED = "io.twohire.bleintsdk.bluetooth.ACTION_STATE_CHANGED"

    const val ACTION_CONNECT_COMPLETE = "io.twohire.bleintsdk.bluetooth.ACTION_CONNECT_COMPLETE"
    const val ACTION_CONNECT_ERROR = "io.twohire.bleintsdk.bluetooth.ACTION_CONNECT_ERROR"

    const val ACTION_WRITE_COMPLETE = "io.twohire.bleintsdk.bluetooth.ACTION_WRITE_COMPLETE"
    const val ACTION_WRITE_ERROR = "io.twohire.bleintsdk.bluetooth.ACTION_WRITE_ERROR"

    const val ACTION_READ_COMPLETE = "io.twohire.bleintsdk.bluetooth.ACTION_READ_COMPLETE"
    const val ACTION_READ_DATA = "io.twohire.bleintsdk.bluetooth.ACTION_READ_DATA"
    const val ACTION_READ_ERROR = "io.twohire.bleintsdk.bluetooth.ACTION_READ_ERROR"

    const val ACTION_EXTRA_DATA = "io.twohire.bleintsdk.bluetooth.ACTION_EXTRA_DATA"
}