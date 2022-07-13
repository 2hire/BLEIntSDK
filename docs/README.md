# BLE Integration

## Preamble

During the whole flow the user requesting to open a vehicle has two timeframes where internet connection is mandatory, when requesting permission to act on a vehicle, and when releasing the control on the vehicle by ending the session.

## Table of contents

- [Endpoints](endpoints.md#endpoints)
  - [Constants](endpoints.md#constants)
  - [Starting a offline session](endpoints.md#starting-a-offline-session)
    - [Request params](endpoints.md#request-params)
    - [Request body](endpoints.md#request-body)
    - [200 - Success Response](endpoints.md#200---success-response)
    - [500 - Error response `PROFILE_ERROR`](endpoints.md#500---error-response-profile_error)
    - [400 - Error response `SESSION_ERROR`](endpoints.md#400---error-response-session_error)
  - [Ending a offline session](endpoints.md#ending-a-offline-session)
    - [Request params](endpoints.md#request-params-1)
    - [Request body](endpoints.md#request-body-1)
    - [200 - Success Response](endpoints.md#200---success-response-1)
    - [400 - Error response `SESSION_ERROR`](endpoints.md#400---error-response-session_error-1)
- [BLEIntSDK](sdk.md)
  - [Native SDKs](sdk.md#native-sdks)
  - [Cross-platform bridges](sdk.md#cross-platform-bridges)
  - [Example Applications](sdk.md#example-applications)
