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

Before creating a session with a vehicle, a server session must be created using [`start_offline_session`](../../docs/endpoints.md#starting-a-offline-session) endpoint.

Create a BLEIntSDK Client instance with data received from the endpoint. See [errors](../../docs/sdk.md#error-codes) for other error codes.

```ts
import type * as SDK from '@2hire/bleintsdk-types';

const commandsHistory: string[] = [];

// ...

// data received from start_offline_session endpoint
const accessDataToken = "session_token";
const publicKey = "board_public_key";
const commands: SDK.Commands = {
  start: "start_command_payload",
  stop: "stop_command_payload",
  end_session: "end_session_command_payload",
};

try {
  const result = await cordova.plugins.BLEIntSDKCordova.sessionSetup(accessDataToken, commands, publicKey);

  console.log(result); // true
} catch (e) {
  if (e.code === "invalid_data") {
    // data supplied is not correct. e.g. wrong format?
  }
}
```

### Connect to a vehicle

Connect to a board and start the session. See [errors](../../docs/sdk.md#error-codes) for other error codes.

```ts
// board mac address is received from start_offline_session endpoint
const boardMacAddress = "mac_address";

try {
  // connect to vehicle using `boardMacAddress`
  const result = await cordova.plugins.BLEIntSDKCordova.connect(
    boardMacAddress
  );

  // save base64 result.payload command response
  commandsHistory.push(result.payload)

  console.log(result); // { success: true, payload: "efab2331..." }
} catch (e) {
  if (e.code === "invalid_session") {
    // session is not valid. e.g. call server o get a new one
  }
}

```

### Send a command to a vehicle

Available commands are _Start_ and _Stop_. See [errors](../../docs/sdk.md#error-codes) for other error codes.

```ts
try {
  const result = await cordova.plugins.BLEIntSDKCordova.sendCommand("start");

  // save base64 result.payload command response
  commandsHistory.push(result.payload)

  console.log(result); // { success: true, payload: "efab2331..." }
} catch(e) {
  if (e.code === "timeout") {
    // command timed out. e.g. retry?
  }
}
```

### End a session

End the board session and clear the client instance. After ending a board session all payloads received must be then sent back to the server using [`end_offline_session`](../../docs/endpoints.md#ending-a-offline-session). See [errors](../../docs/sdk.md#error-codes) for other error codes.

```ts
try {
  const result = await cordova.plugins.BLEIntSDKCordova.endSession();

  // save base64 result.payload command response
  commandsHistory.push(result.payload)

  console.log(result); // { success: true, payload: "efab2331..." }

  // endServerSession(commandsHistory)
} catch(e) {
  if (e.code === "timeout") {
    // command timed out. e.g. retry?
  }
}
```
