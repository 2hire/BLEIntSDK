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

### Environment variables

Using the application with a mock board

| Variable                       | Description                    |
|--------------------------------|--------------------------------|
| USE_MOCK                       | Required, Use mock board       |
| MOCK_BOARD_IDENTIFIER          | Mock board identifier          |
| MOCK_BOARD_PUBKEY              | Mock board public key          |
| MOCK_BOARD_COMMAND_START       | Mock board Start command       |
| MOCK_BOARD_COMMAND_STOP        | Mock board Stop command        |
| MOCK_BOARD_COMMAND_NOOP        | Mock board Noop command        |
| MOCK_BOARD_COMMAND_LOCATE      | Mock board Locate command      |
| MOCK_BOARD_COMMAND_END_SESSION | Mock board End Session command |

Using the application with 2hireAsAdapter. (Only for testing purposes)

| Variable                       | Description                        |
|--------------------------------|------------------------------------|
| TWOAA_CLIENT_ID                | Required, 2hireAsAdapter client id |
| TWOAA_HOST                     | Required, 2hireAsAdapter host      |
| TWOAA_SECRET                   | Required, 2hireAsAdapter secret    |
| TWOAA_ENV                      | Environment                        |
