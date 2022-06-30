# @2hire/cordova-plugin-bleintsdk

Cordova plugin for BLEIntSDK

## Installation

```sh
npm install @2hire/cordova-plugin-bleintsdk
```

## Usage

### Setup a new session

```ts
import type * as SDK from '@2hire/bleintsdk-types';

// ...

const commands: SDK.Commands = {
  start: "start_command_payload",
  stop: "stop_command_payload",
  noop: "noop_command_payload",
  locate: "locate_command_payload",
  end_session: "end_session_command_payload",
};

const result = await cordova.plugins.BLEIntSDKCordova.sessionSetup("token", commands, "pubKey");
console.log(result); // true
```

### Connect to a vehicle

```ts
// ...

const result = await cordova.plugins.BLEIntSDKCordova.connect("vehicle_identifier");
console.log(result); // { success: true, payload: ... }
```

### Send a command to a vehicle

```ts
// ...

const result = await cordova.plugins.BLEIntSDKCordova.sendCommand("start");
console.log(result); // { success: true, payload: ... }
```

### End a session

```ts
// ...

const result = await cordova.plugins.BLEIntSDKCordova.endSession();
console.log(result); // { success: true, payload: ... }
```
