# BLEIntSDK

This repository is the home of 2hire's BLEIntSDK and related libraries.

## Documentation

Extended documentation can be found [here](docs/README.md).

## Published Packages

### Native SDKs

| Package                                   | Platform | Version                                                                                                  | License |
| ----------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------- | ------- |
| [2hire-BLEIntSDK](packages/sdk/ios/core)  | iOS      | [![version](https://badgen.net/cocoapods/v/2hire-BLEIntSDK)](https://cocoapods.org/pods/2hire-BLEIntSDK) | MIT     |
| [BLEIntSDK-Android](packages/sdk/android) | Android  | [![version](https://jitpack.io/v/2hire/BLEIntSDK.svg)](https://jitpack.io/#2hire/BLEIntSDK)              | MIT     |

#### Cross-platform bridges

| Package                                                              | Version                                                                                                                               | License |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| [@2hire/react-native-bleintsdk](packages/react-native-bleintsdk)     | [![version](https://badgen.net/npm/v/@2hire/react-native-bleintsdk)](https://www.npmjs.com/package/@2hire/react-native-bleintsdk)     | MIT     |
| [@2hire/cordova-plugin-bleintsdk](packages/cordova-plugin-bleintsdk) | [![version](https://badgen.net/npm/v/@2hire/cordova-plugin-bleintsdk)](https://www.npmjs.com/package/@2hire/cordova-plugin-bleintsdk) | MIT     |

#### Utilities

| Package                                            | Target     | Version                                                                                                             | License |
| -------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------- | ------- |
| [@2hire/bleintsdk-types](packages/bleintsdk-types) | Typescript | [![version](https://badgen.net/npm/v/@2hire/bleintsdk-types)](https://www.npmjs.com/package/@2hire/bleintsdk-types) | MIT     |

## Examples

Example applications using the SDKs.

- [SwiftUI](examples/ios/) Cocoapods, iOS only.
- [ionic-cordova](examples/ionic-cordova/) with Angular 13, Android and iOS.
- [react-native](examples/react-native/) Android and iOS.
