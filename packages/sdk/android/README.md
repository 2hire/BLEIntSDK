# io.twohire.bleintsdk

[![version](https://jitpack.io/v/2hire/BLEIntSDK.svg)](https://jitpack.io/#2hire/BLEIntSDK)

## Requirements

Add the service dependency in your `app/AndroidManifest.xml`:

```xml
<application>
    <service
        android:name="io.twohire.bleintsdk.bluetooth.BluetoothLeService"
        android:enabled="true" />
</application>
```

### Permissions

These are SDKs needed permissions

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

Following [this](https://developer.android.com/reference/android/bluetooth/le/BluetoothLeScanner#startScan(android.bluetooth.le.ScanCallback)) link:

> An app must have [ACCESS_COARSE_LOCATION](https://developer.android.com/reference/android/Manifest.permission#ACCESS_COARSE_LOCATION)
permission in order to get results. An App targeting Android Q or later must have
[ACCESS_FINE_LOCATION](https://developer.android.com/reference/android/Manifest.permission#ACCESS_FINE_LOCATION)
permission in order to get results.
For apps targeting [Build.VERSION_CODES#R](https://developer.android.com/reference/android/os/Build.VERSION_CODES#R)
or lower, this requires the [Manifest.permission#BLUETOOTH_ADMIN](https://developer.android.com/reference/android/Manifest.permission#BLUETOOTH_ADMIN)
permission which can be gained with a simple `<uses-permission>` manifest tag.
For apps targeting [Build.VERSION_CODES#S](https://developer.android.com/reference/android/os/Build.VERSION_CODES#S)
or or higher, this requires the [Manifest.permission#BLUETOOTH_SCAN](https://developer.android.com/reference/android/Manifest.permission#BLUETOOTH_SCAN)
permission which can be gained with
[Activity.requestPermissions(String[], int)](https://developer.android.com/reference/android/app/Activity#requestPermissions(java.lang.String[],%20int)).
In addition, this requires either the [Manifest.permission#ACCESS_FINE_LOCATION](https://developer.android.com/reference/android/Manifest.permission#ACCESS_FINE_LOCATION)
permission or a strong assertion that you will never derive the physical location of the device.
You can make this assertion by declaring `usesPermissionFlags="neverForLocation"` on the relevant
`<uses-permission>` manifest tag, but it may restrict the types of Bluetooth devices you can interact with.

## Installation

io.twohire.bleintsdk is available through [JitPack](https://jitpack.io/#2hire/BLEIntSDK/Tag). To install
it, add the following line to your build.gradle:

```gradle
allprojects {
  repositories {
    // ...
    maven { url 'https://jitpack.io' }
  }
}
```

add the dependency:

```gradle
dependencies {
  implementation 'com.github.2hire:BLEIntSDK:Tag'
}
```

## Getting started

### Create a Client instance

Before creating a session with a vehicle, a server session must be created using [`start_offline_session`](../../../docs/endpoints.md#starting-a-offline-session) endpoint.

Create a Client instance with data received from the endpoint. See [errors](../../../docs/sdk.md#error-codes) for other error codes.

```kotlin
import io.twohire.bleintsdk.client.*

// ...

var commandsHistory = emptyArray<String>()

// create a new BLEIntSDK.Client instance
this.client = Client()

// data received from start_offline_session endpoint
val accessToken = "access_token"
val publicKey = "public_key"
val commands: Commands = mapOf(
    CommandType.Start to "start_command_payload",
    CommandType.Stop to "start_command_payload",
    CommandType.EndSession to "end_session_command_payload"
)

try {
    // create session data
    val sessionConfig = SessionConfig(accessToken, publicKey, commands)

    // setup client with session data
    this.client.sessionSetup(applicationContext, sessionConfig)
} catch (e: BLEIntSDKException) {
    if (e.error == BLEIntError.INVALID_DATA) {
        // data supplied is not correct. e.g. wrong format?
    }
}
```

### Connect to a vehicle

Connect to a board and start the session. See [errors](../../../docs/sdk.md#error-codes) for other error codes.

```kotlin
import io.twohire.bleintsdk.client.*

// ...

try {
// board mac address is received from start_offline_session endpoint
    val boardMacAddress = "mac_address"

// connect to vehicle using `boardMacAddress`
    val response = this.client.connect(applicationContext, boardMacAddress)

// convert response payload to base64
    val base64Response = Base64.encodeToString(response.additionalPayload, Base64.NO_WRAP)

// save command response
    commandsHistory += base64Response

    println(base64Response)  // efab2331....
    println(response.success)  // true
} catch (e: BLEIntSDKException) {
    if (e.error == BLEIntError.INVALID_SESSION) {
        // session is not valid. e.g. call server to get a new one
    }
}
```

### Send command to vehicle

Send a command to a vehicle. Available commands are _Start_ and _Stop_. See [errors](../../../docs/sdk.md#error-codes) for other error codes.

```kotlin
import io.twohire.bleintsdk.client.*

// ...

try {
    // send a command to a connected vehicle
    val response = this.client.sendCommand(CommandType.Start)

    // convert response payload to base64
    val base64Response = Base64.encodeToString(response.additionalPayload, Base64.NO_WRAP)

    // save command response
    commandsHistory += base64Response

    println(base64Response)  // efab2331....
    println(response.success)  // true
} catch (e: BLEIntSDKException) {
    if (e.error == BLEIntError.TIMEOUT) {
        // command timed out. e.g. retry?
    }
}
```

### End board session

End the board session and clear the client instance. After ending a board session all payloads received must be then sent back to the server using [`end_offline_session`](../../../docs/endpoints.md#ending-a-offline-session). See [errors](../../../docs/sdk.md#error-codes) for other error codes.

```kotlin
import io.twohire.bleintsdk.client.*

// ...

try {
    // close the board session
    val response = this.client.endSession()

    // convert response payload to base64
    val base64Response = Base64.encodeToString(response.additionalPayload, Base64.NO_WRAP)

    // save command response
    commandsHistory += base64Response

    println(base64Response)  // efab2331....
    println(response.success)  // true

    // endServerSession(commandsHistory)

} catch (e: BLEIntSDKException) {
    if (e.error == BLEIntError.TIMEOUT) {
        // command timed out. e.g. retry?
    }
}
```

## Author

[2hire](https://2hire.io), info@2hire.io

## License

2hire-BLEIntSDK is available under the MIT license. See the LICENSE file for more info.
