# @2hire/cordova-plugin-bleintsdk

Cordova plugin for BLEIntSDK

## Installation

```sh
npm install @2hire/cordova-plugin-bleintsdk
```

Add the plugin in package.json

```jsonc
{
  "cordova": {
    // ...
    "plugins": {
      // ...
      "@2hire/cordova-plugin-bleintsdk": {},
    }
  }
}
```

## Usage

### Setup a new session

Before creating a session with a vehicle, a server session must be created using [`start_offline_session`](../../../../docs/endpoints.md#starting-a-offline-session) endpoint.

Create a BLEIntSDK Client instance with data received from the endpoint.

```ts
import type * as SDK from '@2hire/bleintsdk-types';

const commandsHistory: string[] = [];

// ...

// data received from start_offline_session endpoint
const accessDataToken = "session_roken";
const publicKey = "board_public_key";
const commands: SDK.Commands = {
  start: "start_command_payload",
  stop: "stop_command_payload",
  noop: "noop_command_payload",
  end_session: "end_session_command_payload",
};

const result = await cordova.plugins.BLEIntSDKCordova.sessionSetup(accessDataToken, commands, publicKey);

console.log(result); // true
```

### Connect to a vehicle

Connect to a board and start the session.

```ts
// board mac address is received from start_offline_session endpoint
const boardMacAddress = "mac_address"

// connect to vehicle using `boardMacAddress`
const result = await cordova.plugins.BLEIntSDKCordova.connect(boardMacAddress);

// save base64 result.payload command response
commandsHistory.push(result.payload)

console.log(result); // { success: true, payload: "efab2331..." }
```

### Send a command to a vehicle

Available commands are _Start_ and _Stop_.

```ts
const result = await cordova.plugins.BLEIntSDKCordova.sendCommand("start");

// save base64 result.payload command response
commandsHistory.push(result.payload)

console.log(result); // { success: true, payload: "efab2331..." }
```

### End a session

End the board session and clear the client instance. After ending a board session all payloads received must be then sent back to the server using [`end_offline_session`](../docs/endpoints.md#ending-a-offline-session).

```ts
const result = await cordova.plugins.BLEIntSDKCordova.endSession();

// save base64 result.payload command response
commandsHistory.push(result.payload)

console.log(result); // { success: true, payload: "efab2331..." }

// endServerSession(commandsHistory)
```
