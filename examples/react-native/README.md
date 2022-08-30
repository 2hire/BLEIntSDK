# React-Native Example

This an example project using React Native.
See [App.tsx](src/App.tsx) for the main functionality.

## Getting started

```bash
    yarn install
    yarn ios
```

### Linking local packages

```bash
    # Create a global link
    $ cd ../../react-native-bleintsdk
    $ yarn link
    success Registered "@2hire/bleintsdk-types".
    info You can now run `yarn link "@2hire/bleintsdk-types"` in the projects where you want to use this package and it will be used instead.

    # Create a global link
    $ cd ../bleintsdk-types
    $ yarn link
    success Registered "@2hire/react-native-bleintsdk".
    info You can now run `yarn link "@2hire/react-native-bleintsdk"` in the projects where you want to use this package and it will be used instead.

    # Go back to the example project and link the packages
    $ cd ../../examples/react-native
    $ yarn link "@2hire/bleintsdk-types"
    $ yarn link "@2hire/react-native-bleintsdk"
```

## Development

During development can be useful to test the application with a board.

### Environment variables

#### Using the application with a test board

| Variable                       | Description                 |
| ------------------------------ | --------------------------- |
| TEST_BOARD                     | Required to use mock board  |
| TEST_BOARD_IDENTIFIER          | Board identifier            |
| TEST_BOARD_PUBKEY              | Board public key            |
| TEST_BOARD_COMMAND_START       | Start command payload       |
| TEST_BOARD_COMMAND_STOP        | Stop command payload        |
| TEST_BOARD_COMMAND_END_SESSION | End Session command payload |

#### Using the application with 2hireAsAdapter

A Third party app should **never** call 2aa directly, from [here](../../docs/endpoints.md#endpoints):

>All the endpoints [...] are meant to be implemented by a Third party backend and exposed by it to a Third party app via an authenticated endpoint. **The Third party app will never directly communicate with the 2hire as Adapter (2aa) backend**.

Use this envs only for testing purposes.

| Variable        | Description                        |
| --------------- | ---------------------------------- |
| TWOAA_CLIENT_ID | Required, 2hireAsAdapter client id |
| TWOAA_HOST      | Required, 2hireAsAdapter host      |
| TWOAA_SECRET    | Required, 2hireAsAdapter secret    |
