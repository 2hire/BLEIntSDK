export interface BLEIntSdk {
  sessionSetup: (
    accessToken: string,
    commands: Commands,
    publicKey: string
  ) => Promise<boolean>;
  connect: (address: string) => Promise<CommandResponse>;
  sendCommand: (command: CommandType) => Promise<CommandResponse>;
  endSession: () => Promise<CommandResponse>;
}

export type CommandType = "start" | "stop" | "noop" | "end_session";

export type Commands = Record<CommandType, string>;

export type CommandResponse = {
  success: boolean;
  payload: string;
} | null;

export type ErrorCode =
  | "invalid_data"
  | "invalid_state"
  | "invalid_session"
  | "not_connected"
  | "timeout"
  | "peripheral_not_found"
  | "internal";