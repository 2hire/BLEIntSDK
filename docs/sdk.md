# BLEIntSDK

Flow of a session:

- Create a new session with [`start_offline_session`](./endpoints.md#starting-a-offline-session).
- Create a new BLEIntSDK Client with `accessDataToken`, `publicKeyBox`, `commands` received from the endpoint.
- Connect to the vehicle with `macAddressBox` and start the board session.
- Send commands to vehicle.
- Close the session by calling [`end_offline_session`](./endpoints.md#ending-a-offline-session) with all the commands payload received from the board.

## Error codes

Error codes that SDKs can send.

| Code                   | Description                                                                       |
| ---------------------- | --------------------------------------------------------------------------------- |
| `invalid_data`         | Bad data format while creating a Client instance.                                 |
| `invalid_state`        | Client is not in the right state. E.g. calling any command before `sessionSetup`. |
| `invalid_session`      | Session was refused by the board. E.g. might be already expired.                  |
| `invalid_command`      | Command was refused by the board. E.g. encrypted payload might not be right.      |
| `not_connected`        | Bluetooth is not in connected state.                                              |
| `timeout`              | Bluetooth action timed out.                                                       |
| `peripheral_not_found` | Bluetooth peripheral not found.                                                   |
| `internal`             | Internal error.                                                                   |

## Native SDKs

- [2hire-BLEIntSDK](../packages/sdk/ios/core), iOS and Swift.
- [BLEIntSDK-Android](../packages/sdk/android), Android and Kotlin.

## Cross-platform bridges

- [@2hire/react-native-bleintsdk](../packages/react-native-bleintsdk), React Native bridge.
- [@2hire/cordova-plugin-bleintsdk](../packages/cordova-plugin-bleintsdk), Cordova plugin.

## Example Applications

- [SwiftUI](../examples/ios) Cocoapods, iOS only.
- [ionic-cordova](../examples/ionic-cordova) with Angular 13, Android and iOS.
- [react-native](../examples/react-native) Android and iOS.
