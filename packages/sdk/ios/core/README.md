# 2hire-BLEIntSDK

[![Version](https://img.shields.io/cocoapods/v/2hire-BLEIntSDK.svg?style=flat)](https://cocoapods.org/pods/2hire-BLEIntSDK)
[![License](https://img.shields.io/cocoapods/l/2hire-BLEIntSDK.svg?style=flat)](https://cocoapods.org/pods/2hire-BLEIntSDK)
[![Platform](https://img.shields.io/cocoapods/p/2hire-BLEIntSDK.svg?style=flat)](https://cocoapods.org/pods/2hire-BLEIntSDK)

## Requirements

In order to your application to use bluetooth add _Privacy - Location Always Usage Description_ key (empty value or not. It is better to define a value to a custom / more user-friendly message).

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Testing</string>
```

## Installation

2hire-BLEIntSDK is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod '2hire-BLEIntSDK'
```

## Example

To run the example project, clone the repo, and run `pod install` from the Example [directory](/examples/ios/) first.

## Getting started

### Create a Client instance

Before creating a session with a vehicle, a server session must be created using [`start_offline_session`](../../../../docs/endpoints.md#starting-a-offline-session) endpoint.

Create a BLEIntSDK Client instance with data received from the endpoint. See [errors](../../../../docs/sdk.md#error-codes) for other error codes.

```swift
import BLEIntSDK

// ...

var commandsHistory: [String] = []

// create a new BLEIntSDK.Client instance
let client = Client()

// data received from start_offline_session endpoint
let accessDataToken = "session_token"
let publicKey = "board_public_key"
let commands: Commands = [
    .Start:
        "start_command_payload",
    .Stop:
        "stop_command_payload",
    .Noop:
        "noop_command_payload",
    .EndSession:
        "end_session_command_payload",
]

do {
    // create session data
    let sessionData = SessionData(accessToken: accessDataToken, publicKey: publicKey, commands: commands)

    // setup client with session data
    try client.sessionSetup(
        with: sessionData
    )
}
catch let error as BLEIntSDKError {
    if error  == .InvalidData {
        // data supplied is not correct. e.g. wrong format?
    }
}
```

### Connect to a vehicle

Connect to a board and start the session. See [errors](../../../../docs/sdk.md#error-codes) for other error codes.

```swift
import BLEIntSDK

// ...

do {
    // board mac address is received from start_offline_session endpoint
    let boardMacAddress = "mac_address"

    // connect to vehicle using `boardMacAddress`
    let response = try await client.connectToVehicle(withIdentifier: boardMacAddress)

    // convert response payload to base64
    let base64Response = Data(response.additionalPayload).base64EncodedString()

    // save command response
    commandsHistory.append(base64Response)

    print(base64Response)  // efab2331...
    print(response.success.description)  // true
}
catch let error as BLEIntSDKError {
    if error  == .InvalidSession {
        // session is not valid. e.g. call server o get a new one
    }
}
```

### Send command to vehicle

Here's an example to send the _Start_ command to a vehicle. Available commands are _Start_ and _Stop_. See [errors](../../../../docs/sdk.md#error-codes) for other error codes.

```swift
import BLEIntSDK

// ...

do {
    // send a command to a connected vehicle
    let response = try await client.sendCommand(type: .Start)

    // convert response payload to base64
    let base64Response = Data(response.additionalPayload).base64EncodedString()

    // save command response
    commandsHistory.append(base64Response)

    print(base64Response) // efab2331...
    print(response.success.description)  // true
}
catch let error as BLEIntSDKError {
    if error == .Timeout {
        // command timed out. e.g. retry?
    }
}
```

### End session

End the board session and clear the client instance. After ending a board session all payloads received must be then sent back to the server using [`end_offline_session`](../../../../docs/endpoints.md#ending-a-offline-session). See [errors](../../../../docs/sdk.md#error-codes) for other error codes.

```swift
import BLEIntSDK

// ...

do {
    // close the board session
    let response = try await client.endSession()

    // convert response payload to base64
    let base64Response = Data(response.additionalPayload).base64EncodedString()

    // save command response
    commandsHistory.append(base64Response)

    print(base64Response)  // efab2331...
    print(response.success.description)  // true

    // endServerSession(with: commandsHistory)

}
catch let error as BLEIntSDKError {
    if error == .Timeout {
        // command timed out. e.g. retry?
    }
}
```

## Author

[2hire](https://2hire.io), info@2hire.io

## License

2hire-BLEIntSDK is available under the MIT license. See the LICENSE file for more info.
