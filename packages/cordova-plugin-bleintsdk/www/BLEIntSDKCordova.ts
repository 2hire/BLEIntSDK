import { exec } from "cordova";
import type {
  Commands,
  CommandResponse,
  CommandType,
} from "@2hire/bleintsdk-types";

const PluginName = "BLEIntSDKCordova";

const execNativeMethod = <T>(methodName: string, ...args: unknown[]) =>
  new Promise<T>((onSuccess, onError) =>
    exec(onSuccess, onError, PluginName, methodName, args)
  );

export function sessionSetup(
  accessToken: string,
  commands: Commands,
  publicKey: string
): Promise<boolean> {
  return execNativeMethod("sessionSetup", accessToken, commands, publicKey);
}

export function connect(address: string): Promise<CommandResponse> {
  return execNativeMethod("connect", address);
}

export function sendCommand(command: CommandType): Promise<CommandResponse> {
  return execNativeMethod("sendCommand", command);
}

export function endSession(): Promise<CommandResponse> {
  return execNativeMethod("endSession");
}
