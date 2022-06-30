import { NativeModules, Platform } from 'react-native';
import type * as SDK from '@2hire/bleintsdk-types';

const LINKING_ERROR =
  `The package '@2hire/react-native-bleintsdk' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo managed workflow\n';

const ReactNativeBleintSdk = NativeModules.ReactNativeBleintSdk
  ? NativeModules.ReactNativeBleintSdk
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export type Commands = SDK.Commands;
export type CommandResponse = SDK.CommandResponse;
export type CommandType = SDK.CommandType;

export const sessionSetup: SDK.BLEIntSdk['sessionSetup'] = (accessToken, commands, publicKey) =>
  ReactNativeBleintSdk.sessionSetup(accessToken, commands, publicKey);

export const connect: SDK.BLEIntSdk['connect'] = (address) => ReactNativeBleintSdk.connect(address);

export const sendCommand: SDK.BLEIntSdk['sendCommand'] = (command) => ReactNativeBleintSdk.sendCommand(command);

export const endSession: SDK.BLEIntSdk['endSession'] = () => ReactNativeBleintSdk.endSession();
