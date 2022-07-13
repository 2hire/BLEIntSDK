# @2hire/react-native-bleintsdk

React Native bridge for BLEIntSDK

## Installation

```sh
npm install @2hire/react-native-bleintsdk
```

## Usage

### Setup a new session

Before creating a session with a vehicle, a server session must be created using [`start_offline_session`](../docs/endpoints.md#starting-a-offline-session) endpoint.

Create a BLEIntSDK Client instance with data received from the endpoint.

```ts
import * as SDK from "@2hire/react-native-bleintsdk";

// ...

const commandsHistory: string[] = [];

// data received from start_offline_session endpoint
const accessDataToken = "session_roken";
const publicKey = "board_public_key";
const commands: SDK.Commands = {
  start: "start_command_payload",
  stop: "stop_command_payload",
  noop: "noop_command_payload",
  end_session: "end_session_command_payload",
};

const result = await SDK.sessionSetup(accessDataToken, commands, publicKey);

console.log(result); // true
```

### Connect to a vehicle

Connect to a board and start the session.

```ts
import * as SDK from "@2hire/react-native-bleintsdk";

// ...

// board mac address is received from start_offline_session endpoint
const boardMacAddress = "mac_address"

// connect to vehicle using `boardMacAddress`
const result = await SDK.connect(boardMacAddress);

// save base64 result.payload command response
commandsHistory.push(result.payload)

console.log(result); // { success: true, payload: "efab2331..." }
```

### Send a command to a vehicle

Available commands are _Start_ and _Stop_.

```ts
import * as SDK from "@2hire/react-native-bleintsdk";

// ...

const result = await SDK.sendCommand("start");

// save base64 result.payload command response
commandsHistory.push(result.payload)

console.log(result); // { success: true, payload: "efab2331..." }
```

### End a session

End the board session and clear the client instance. After ending a board session all payloads received must be then sent back to the server using [`end_offline_session`](../docs/endpoints.md#ending-a-offline-session).

```ts
import * as SDK from "@2hire/react-native-bleintsdk";

// ...

const result = await SDK.endSession();

// save base64 result.payload command response
commandsHistory.push(result.payload)

console.log(result); // { success: true, payload: "efab2331..." }

// endServerSession(commandsHistory)
```
