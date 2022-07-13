/* eslint-disable react-native/no-inline-styles */
import * as SDK from '@2hire/react-native-bleintsdk';
import {
  TEST_BOARD_COMMAND_END_SESSION,
  TEST_BOARD_COMMAND_NOOP,
  TEST_BOARD_COMMAND_START,
  TEST_BOARD_COMMAND_STOP,
  TEST_BOARD_IDENTIFIER,
  TEST_BOARD_PUBKEY,
  TWOAA_CLIENT_ID,
  TWOAA_SECRET,
  TEST_BOARD,
} from '@env';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as React from 'react';
import {useCallback, useEffect, useRef, useState} from 'react';
import {Alert, PermissionsAndroid, Platform, TextInput, View} from 'react-native';
import styled from 'styled-components';
import {Button} from './components/Button';
import {TwoAAClient} from './utils/TwoAAHelper';

const Commands: SDK.Commands = {
  start: TEST_BOARD_COMMAND_START,
  stop: TEST_BOARD_COMMAND_STOP,
  noop: TEST_BOARD_COMMAND_NOOP,
  end_session: TEST_BOARD_COMMAND_END_SESSION,
};

enum ActionType {
  Create,
  Connect,
  StartCommand,
  StopCommand,
  End,
}

const StorageVehicleIdKey = '@2hire-vehicle-id';

export default function App() {
  const [accessDataToken, setAccessDataToken] = useState<string>('');
  const [loadingAction, setLoadingAction] = useState<ActionType | null>(null);
  const [vehicleId, setVehicleId] = useState<string>('');

  const identifier = useRef(TEST_BOARD_IDENTIFIER);
  const sessionId = useRef<number | null>(null);
  const reports = useRef<string[]>([]);

  useEffect(() => {
    if (!TEST_BOARD) {
      AsyncStorage.getItem(StorageVehicleIdKey)
        .then((value) => {
          if (value != null) {
            setVehicleId(value);
          } else {
            console.log(`${StorageVehicleIdKey} is null`);
          }
        })
        .catch(console.error);
    }
  }, []);

  const handleResponse = useCallback<(res: Promise<SDK.CommandResponse>) => Promise<void>>(async (p) => {
    try {
      const res = await p;

      if (res?.payload) {
        reports.current.push(res.payload);
      }

      showAlert(res);
    } catch (e) {
      showErrorAlert(e);
    } finally {
      setLoadingAction(null);
    }
  }, []);

  return (
    <Wrapper>
      {TEST_BOARD ? (
        <MyTextInput value={accessDataToken} onChangeText={setAccessDataToken} />
      ) : (
        <MyTextInput placeholder="Vehicle ID" value={vehicleId} onChangeText={setVehicleId} />
      )}
      <MyButton
        color="#FF9500"
        disabled={loadingAction !== null || (!TEST_BOARD && vehicleId.length === 0)}
        isLoading={loadingAction === ActionType.Create}
        title="Create"
        style={{marginBottom: 'auto'}}
        onPress={async () => {
          if (Platform.OS === 'android') {
            requestAndroidPermissions();
          }

          setLoadingAction(ActionType.Create);

          try {
            if (TEST_BOARD) {
              const response = await SDK.sessionSetup(accessDataToken, Commands, TEST_BOARD_PUBKEY);

              console.log(response);
            } else {
              const _vehicleId = vehicleId.trim();

              await AsyncStorage.setItem(StorageVehicleIdKey, _vehicleId);
              await TwoAAClient.auth(TWOAA_CLIENT_ID, TWOAA_SECRET);

              const {
                data: {accessDataToken: token, commands, publicKeyBox, macAddressBox, ...data},
              } = await TwoAAClient.startOfflineSession(_vehicleId);

              reports.current = [];
              sessionId.current = data.sessionId;

              console.log({token, commands, publicKeyBox, macAddressBox, ...data});

              const response = await SDK.sessionSetup(
                token,
                {
                  start: '',
                  stop: '',
                  noop: '',
                  end_session: '',
                  ...commands,
                },
                publicKeyBox,
              );
              identifier.current = macAddressBox;

              console.log(response);
            }
          } catch (e) {
            showErrorAlert(e);
          } finally {
            setLoadingAction(null);
          }
        }}
      />
      <MyButton
        color="#35C759"
        disabled={loadingAction !== null}
        isLoading={loadingAction === ActionType.Connect}
        title="Start sequence"
        onPress={() => {
          setLoadingAction(ActionType.Connect);

          handleResponse(SDK.connect(identifier.current));
        }}
      />
      <MyButton
        color="#FF3B2F"
        disabled={loadingAction !== null}
        isLoading={loadingAction === ActionType.End}
        title="End session"
        onPress={async () => {
          setLoadingAction(ActionType.End);

          await handleResponse(SDK.endSession());

          if (!TEST_BOARD && sessionId.current !== null) {
            try {
              const response = await TwoAAClient.endOfflineSession(vehicleId, sessionId.current, reports.current);

              console.log(response);
            } catch (e) {
              showErrorAlert(e);
            } finally {
              setLoadingAction(null);
            }
          }
        }}
      />
      <MyButton
        color="#007AFF"
        disabled={loadingAction !== null}
        isLoading={loadingAction === ActionType.StartCommand}
        title="Start command"
        onPress={async () => {
          setLoadingAction(ActionType.StartCommand);

          await handleResponse(SDK.sendCommand('start'));
        }}
      />
      <MyButton
        color="#007AFF"
        disabled={loadingAction !== null}
        isLoading={loadingAction === ActionType.StopCommand}
        title="Stop command"
        style={{marginBottom: 'auto'}}
        onPress={async () => {
          setLoadingAction(ActionType.StopCommand);

          await handleResponse(SDK.sendCommand('stop'));
        }}
      />
    </Wrapper>
  );
}

const showAlert = (res: SDK.CommandResponse | boolean) =>
  Alert.alert(
    'Command Response',
    res === null
      ? 'Command response is null'
      : `Command was ${(typeof res === 'boolean' ? res : res.success) ? 'successful' : 'unsuccessful'}`.concat(
          typeof res !== 'boolean' ? ` with additional data: ${res.payload}` : '',
        ),
  );

const showErrorAlert = (error: unknown) => {
  console.error(error);

  if (error instanceof Error) {
    Alert.alert('An error occurred', error.message, [
      {
        style: 'default',
        text: 'Show More',
        onPress: () => Alert.alert('An error occurred', JSON.stringify(error)),
      },
      {
        text: 'OK',
      },
    ]);
  } else {
    Alert.alert('An error occurred', JSON.stringify(error));
  }
};

const requestAndroidPermissions = () =>
  PermissionsAndroid.requestMultiple([
    PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT,
    PermissionsAndroid.PERMISSIONS.BLUETOOTH_SCAN,
    PermissionsAndroid.PERMISSIONS.ACCESS_COARSE_LOCATION,
    PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
  ])
    .then(console.log)
    .catch(console.error);

const Wrapper = styled(View)`
  flex: 1;
  align-items: center;
  justify-content: center;
  padding: 16px;
  padding-top: 64px;
`;

const MyTextInput = styled(TextInput)`
  border-radius: 4px;
  border: 1px solid black;
  margin-bottom: 16px;
  margin-top: auto;
  min-height: 24px;
  text-align: center;
  width: 100%;
`;

const MyButton = styled(Button).attrs({textColor: '#ffffff', indicatorColor: '#666666'})<{color?: string}>`
  align-items: center;
  background-color: ${({color}) => color ?? 'transparent'};
  border-radius: 8px;
  justify-content: center;
  margin-bottom: 8px;
  margin-top: 8px;
  min-height: 42px;
  width: 100%;
`;
