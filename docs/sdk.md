# BLEIntSDK

Flow of a session:

- Create a new session with [`start_offline_session`](./endpoints.md#starting-a-offline-session).
- Create a new BLEIntSDK Client with `accessDataToken`, `publicKeyBox`, `commands` received from the endpoint.
- Connect to the vehicle with `macAddressBox` and start the board session.
- Send commands to vehicle.
- Close the session by calling [`end_offline_session`](./endpoints.md#ending-a-offline-session) with all the commands payload received from the board.

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
