# @2hire/react-native-bleintsdk

React Native bridge for BLEIntSDK

## Installation

```sh
npm install @2hire/react-native-bleintsdk
```

## Usage

### Setup a new session

```ts
import * as SDK from "@2hire/react-native-bleintsdk";

// ...

const commands: SDK.Commands = {
  start: "start_command_payload",
  stop: "stop_command_payload",
  noop: "noop_command_payload",
  end_session: "end_session_command_payload",
};

const result = await SDK.sessionSetup("token", commands, "pubKey");
console.log(result); // true
```

### Connect to a vehicle

```ts
// ...

const result = await SDK.connect("vehicle_identifier");
console.log(result); // { success: true, payload: ... }
```

### Send a command to a vehicle

```ts
// ...

const result = await SDK.sendCommand("start");
console.log(result); // { success: true, payload: ... }
```

### End a session

```ts
// ...

const result = await SDK.endSession();
console.log(result); // { success: true, payload: ... }
```
