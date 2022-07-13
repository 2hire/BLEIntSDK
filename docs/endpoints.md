# Endpoints

All the endpoints described in this document are meant to be implemented by a Third party backend and exposed by it to a Third party app via an authenticated endpoint. The Third party app will never directly communicate with the 2hire as Adapter (2aa) backend.

### Constants

**`Base url: https://adapter.2hire.io/api/v1`**

**`Authorization header: "Authorization":"Bearer {JWT_TOKEN}"`**

### Starting a offline session

This endpoint is used to gather the needed encrypted data to start a bluetooth communication session with the box, it's the first step that has to be performed in order to communicate with the vehicle.

**`[POST]/vehicle/:uuid/command/specific/start_offline_session`**

#### Request params

| Parameter | Type     | Description                                            |
| --------- | -------- | ------------------------------------------------------ |
| `uuid`    | `string` | UUID of the vehicle, used to identify a vehicle in 2aa |

#### Request body

| Parameter            | Type            | Description                                                                                                         |
| -------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------- |
| `timestamp`          | `number`        | UNIX timestamp in seconds when the offline session will expire. Ex: 1646752878 → Tuesday, 8 March 2022 15:21:18 GMT |
| `allowedCommands`    | `Array<string>` | Array containing the commands that the end user will be able to perform using the bluetooth session                 |
| `allowedCommands[n]` | `string`        | Command that the user is able to perform during the bluetooth session, can be either start or stop                  |

#### 200 - Success Response

| Parameter                   | Type      | Description                                                                                                                          |
| --------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `success`                   | `boolean` | true when the command has been successfully executed, false when the box has encountered an error                                    |
| `data`                      | `object`  | Object containing the data necessary to start an offline session with the vehicle                                                    |
| `data.version`              | `number`  | Version of the protocol used to communicate with the box                                                                             |
| `data.sessionId`            | `number`  | Unique identifier for the session, it is used to reference the session in other endpoints                                            |
| `data.accessDataToken`      | `string`  | Encrypted message encoded in base64 to be sent to the box together with the app public key in order to start bluetooth communication |
| `data.publicKeyBox`         | `string`  | Public key of the box for this session, it is used to decode the messages that the box will send to the user's device                |
| `data.macAddressBox`        | `string`  | MAC address of the box, used to identify the box on the Bluetooth channel                                                            |
| `data.commands`             | `object`  | Object containing the encrypted and encoded strings used to perform each of the available commands                                   |
| `data.commands[commandKey]` | `string`  | Encrypted string, encoded in base64, used to execute the specific command on the box                                                 |

#### 500 - Error response `PROFILE_ERROR`

Triggered when the box has not been configured to support Bluetooth interactions

| Parameter       | Type     | Description                                                                                        |
| --------------- | -------- | -------------------------------------------------------------------------------------------------- |
| `code`          | `string` | Descriptive identifier of the issue, can just be `PROFILE_ERROR` in this scenario                  |
| `details`       | `object` | Object containing more info about the error                                                        |
| `details.cause` | `string` | Descriptive identifier of the cause of the error, can just be `PROFILE_NOT_VALID` in this scenario |
| `errorId`       | `string` | UUID-V4 that can be used to report the error to the 2hire support team                             |

#### 400 - Error response `SESSION_ERROR`

Triggered whenever the commands provided are not available on the specific box

| Parameter       | Type     | Description                                                                                         |
| --------------- | -------- | --------------------------------------------------------------------------------------------------- |
| code            | `string` | Descriptive identifier of the issue, can just be `SESSION_ERROR` in this scenario                   |
| `details`       | `object` | Object containing more info about the error                                                         |
| `details.cause` | `string` | Descriptive identifier of the cause of the error, can just be `NO_COMMAND_ALLOWED` in this scenario |
| `errorId`       | `string` | UUID-V4 that can be used to report the error to the 2hire support team                              |

### Ending a offline session

This endpoint is used to end a offline session by providing the history of the commands executed on the offline box, the history will be validated to prevent bad actors sending only part of the session to trick the third party backend in thinking the vehicle is currently in a status it is not. This is especially useful in the scenario when an application has been compromised.

**`[POST]/vehicle/:uuid/command/specific/end_offline_session`**

#### Request params

| Parameter | Type     | Description                                            |
| --------- | -------- | ------------------------------------------------------ |
| `uuid`    | `string` | UUID of the vehicle, used to identify a vehicle in 2aa |

#### Request body

| Parameter    | Type            | Description                                    |
| ------------ | --------------- | ---------------------------------------------- |
| `sessionId`  | `number`        | Unique identifier for the session              |
| `history`    | `Array<string>` | Array of the encoded command responses         |
| `history[n]` | `string`        | Encoded command response received from the box |

#### 200 - Success Response

| Parameter | Type      | Description                                                                                                                                      |
| --------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `success` | `boolean` | true if the command was successful, false otherwise. Due to this endpoint being backend only it will always be true or an error will be returned |

#### 400 - Error response `SESSION_ERROR`

| Parameter       | Type     | Description                                                                                                                                                                                                                            |
| --------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `code`          | `string` | Descriptive identifier of the issue, can just be `SESSION_ERROR` in this scenario                                                                                                                                                      |
| `details`       | `object` | Object containing more info about the error                                                                                                                                                                                            |
| `details.cause` | `string` | Descriptive identifier of the cause of the error, can be `SESSION_NOT_FOUND`, when the provided session id doesn't match any session, or INVALID_HISTORY when the history provided cannot be validated and it's considered compromised |
| `errorId`       | `string` | UUID-V4 that can be used to report the error to the 2hire support team                                                                                                                                                                 |
