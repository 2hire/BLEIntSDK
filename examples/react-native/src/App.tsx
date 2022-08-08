/* eslint-disable react-native/no-inline-styles */
import {ErrorCode} from '@2hire/bleintsdk-types';
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
import {Alert, PermissionsAndroid, Platform, TextInput, TouchableOpacity, useColorScheme, View} from 'react-native';
import styled from 'styled-components';
import {Button} from './components/Button';
import {StartOfflineSessionResponse, TwoAAClient} from './utils/TwoAAHelper';

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

type SessionData = StartOfflineSessionResponse & {expire: number};

interface NativeError extends Error {
  code: ErrorCode | string;
}

const isNativeError = (error: unknown): error is NativeError =>
  // @ts-expect-error
  // eslint-disable-next-line dot-notation
  typeof error === 'object' && typeof error?.['code'] === 'string';

const StorageVehicleIdKey = '@2hire-vehicle-id';
const StorageSessionData = '@2hire-last-session';

export default function App() {
  const textColor = useColorScheme() === 'dark' ? 'white' : 'black';

  const [testAccessDataToken, setTestAccessDataToken] = useState<string>('');
  const [loadingAction, setLoadingAction] = useState<ActionType | null>(null);
  const [vehicleId, setVehicleId] = useState<string>('');

  const identifier = useRef(TEST_BOARD_IDENTIFIER);
  const sessionId = useRef<number | null>(null);
  const reports = useRef<string[]>([]);
  const lastSession = useRef<SessionData | null>(null);

  const [resetCount, setResetCount] = useState(0);

  useEffect(() => {
    if (!TEST_BOARD) {
      Promise.all([AsyncStorage.getItem(StorageVehicleIdKey), AsyncStorage.getItem(StorageSessionData)])
        .then(([_vehicleId, _lastSession]) => {
          if (_vehicleId != null) {
            setVehicleId(_vehicleId);
          } else {
            console.log(`${StorageVehicleIdKey} is null`);
          }

          if (_lastSession != null) {
            try {
              const parsedSession = JSON.parse(_lastSession) as SessionData;

              if (parsedSession.expire > Date.now() / 1000) {
                console.log('Session is still valid');

                lastSession.current = parsedSession;
              } else {
                console.log('Session has expired', parsedSession.expire);

                lastSession.current = null;
              }
            } catch (e) {
              console.error(`${StorageSessionData} is not valid`, e);
            }
          } else {
            lastSession.current = null;
            console.log(`${StorageSessionData} is null`);
          }
        })
        .catch(console.error);
    }
  }, []);

  const resetSession = useCallback(() => {
    sessionId.current = null;
    lastSession.current = null;
    identifier.current = TEST_BOARD_IDENTIFIER;
    reports.current = [];

    AsyncStorage.removeItem(StorageSessionData).catch(console.error);
  }, []);

  useEffect(() => {
    if (resetCount === 5) {
      Alert.alert('Warning', 'Are you sure you want to reset the session?', [
        {
          onPress: () => {
            resetSession();
            setResetCount(0);
          },
          text: 'OK',
        },
        {text: 'Cancel', onPress: () => setResetCount(0)},
      ]);
    }
  }, [resetCount, resetSession]);

  const handleResponse = useCallback<(res: Promise<SDK.CommandResponse>) => Promise<void>>(
    async (p) => {
      try {
        const res = await p;

        if (res?.payload) {
          reports.current.push(res.payload);
        }

        showCommandResponseAlert(res);
      } catch (e) {
        if (isNativeError(e) && e.code === 'invalid_session') {
          resetSession();
        }

        showErrorAlert(e);
      } finally {
        setLoadingAction(null);
      }
    },
    [resetSession],
  );

  return (
    <Wrapper>
      {TEST_BOARD ? (
        <MyTextInput style={{color: textColor}} value={testAccessDataToken} onChangeText={setTestAccessDataToken} />
      ) : (
        <MyTextInput
          style={{color: textColor}}
          placeholder="Vehicle ID"
          value={vehicleId}
          onChangeText={setVehicleId}
        />
      )}
      <MyButton
        color="#FF9500"
        disabled={loadingAction !== null || (!TEST_BOARD && vehicleId.length === 0)}
        isLoading={loadingAction === ActionType.Create}
        title="Create session"
        style={{marginBottom: 'auto'}}
        onPress={async () => {
          if (Platform.OS === 'android') {
            requestAndroidPermissions();
          }

          setLoadingAction(ActionType.Create);

          try {
            if (TEST_BOARD) {
              const response = await SDK.sessionSetup(testAccessDataToken, Commands, TEST_BOARD_PUBKEY);

              console.log(response);
            } else if (lastSession.current !== null) {
              const {accessDataToken, commands, publicKeyBox, macAddressBox, ...data} = lastSession.current;

              reports.current = [];
              sessionId.current = data.sessionId;

              console.log({accessDataToken, commands, publicKeyBox, macAddressBox, ...data});

              const response = await SDK.sessionSetup(
                accessDataToken,
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

              Alert.alert('An error occurred', 'A session already exists, must be ended before creating a new one');
            } else {
              const _vehicleId = vehicleId.trim();
              const _expireTimestamp = (Date.now() + 60 * 60 * 24) / 1000;

              await AsyncStorage.setItem(StorageVehicleIdKey, _vehicleId);
              await TwoAAClient.auth(TWOAA_CLIENT_ID, TWOAA_SECRET);

              const {data: startOfflineData} = await TwoAAClient.startOfflineSession(_vehicleId, _expireTimestamp);

              const {accessDataToken, commands, publicKeyBox, macAddressBox, ...data}: SessionData = {
                ...startOfflineData,
                expire: _expireTimestamp,
              };

              reports.current = [];
              sessionId.current = data.sessionId;

              console.log({token: accessDataToken, commands, publicKeyBox, macAddressBox, ...data});

              const response = await SDK.sessionSetup(
                accessDataToken,
                {
                  start: '',
                  stop: '',
                  noop: '',
                  end_session: '',
                  ...commands,
                },
                publicKeyBox,
              );

              lastSession.current = {accessDataToken, commands, publicKeyBox, macAddressBox, ...data};
              await AsyncStorage.setItem(StorageSessionData, JSON.stringify(lastSession.current));

              identifier.current = macAddressBox;

              Alert.alert('Create session', 'Session created!');
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
        color="#007AFF"
        disabled={loadingAction !== null}
        style={{marginTop: 48}}
        isLoading={loadingAction === ActionType.StartCommand}
        title="Start vehicle"
        onPress={async () => {
          setLoadingAction(ActionType.StartCommand);

          await handleResponse(SDK.sendCommand('start'));
        }}
      />
      <MyButton
        color="#007AFF"
        style={{marginBottom: 48}}
        disabled={loadingAction !== null}
        isLoading={loadingAction === ActionType.StopCommand}
        title="Stop vehicle"
        onPress={async () => {
          setLoadingAction(ActionType.StopCommand);

          await handleResponse(SDK.sendCommand('stop'));
        }}
      />
      <MyButton
        color="#FF3B2F"
        disabled={loadingAction !== null}
        isLoading={loadingAction === ActionType.End}
        title="End session"
        style={{marginBottom: 'auto'}}
        onPress={async () => {
          setLoadingAction(ActionType.End);

          await handleResponse(SDK.endSession());

          if (!TEST_BOARD && sessionId.current !== null) {
            try {
              lastSession.current = null;

              await TwoAAClient.auth(TWOAA_CLIENT_ID, TWOAA_SECRET);
              const response = await TwoAAClient.endOfflineSession(vehicleId, sessionId.current, reports.current);

              console.log('Removing session data');
              AsyncStorage.removeItem(StorageSessionData);

              console.log(response);
            } catch (e) {
              showErrorAlert(e);
            } finally {
              setLoadingAction(null);
            }
          }
        }}
      />
      <ResetButton onPress={() => setResetCount(resetCount + 1)} />
    </Wrapper>
  );
}

const ResetButton = styled(TouchableOpacity)`
  background-color: transparent;
  left: 0;
  right: 0;
  height: 50px;
  bottom: 0;
  position: absolute;
`;

const showCommandResponseAlert = (res: SDK.CommandResponse | boolean) =>
  Alert.alert(
    'Command Response',
    res === null
      ? 'Command response is null'
      : `Command was ${(typeof res === 'boolean' ? res : res.success) ? 'successful' : 'unsuccessful'}`.concat(
          typeof res !== 'boolean' ? ` with additional data: ${res.payload}` : '',
        ),
  );

const showErrorAlert = (error: unknown) => {
  console.error(JSON.stringify(error));

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
