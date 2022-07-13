import * as SDK from '@2hire/bleintsdk-types';
import {TWOAA_HOST} from '@env';

type ResponseBody<T> = {
  success: boolean;
  data: T;
};

type ResponseError = {code: string; details: {cause: string}};

type Response<T> = ResponseBody<T> | ResponseError;

type StartOfflineSessionResponse = {
  version: number;
  sessionId: number;
  accessDataToken: string;
  publicKeyBox: string;
  macAddressBox: string;
  commands: Partial<SDK.Commands>;
};

export class TwoAAClient {
  static baseUrl = `https://${TWOAA_HOST}/api/v1`;
  static baseHeaders = {
    'Content-Type': 'application/json',
  };

  static access: {accessToken: string; expiration: Date} | null = null;

  static get isValid() {
    return this.access && +this.access.expiration > Date.now();
  }

  static async auth(clientId: string, clientSecret: string): Promise<typeof TwoAAClient.access> {
    if (this.isValid) {
      return Promise.resolve(this.access);
    }

    const response = await fetch(`${TwoAAClient.baseUrl}/auth`, {
      headers: TwoAAClient.baseHeaders,
      method: 'POST',
      body: JSON.stringify({
        clientId,
        clientSecret,
      }),
    });

    const data = await response.json();

    this.access = {
      accessToken: data.access_token,
      expiration: new Date(Date.now() + parseInt(data.expires_in, 10) * 1000),
    };

    return this.access;
  }

  static async startOfflineSession(uuid: string): Promise<ResponseBody<StartOfflineSessionResponse>> {
    if (!this.isValid) {
      throw 'auth not set';
    }

    const response = await fetch(`${TwoAAClient.baseUrl}/vehicle/${uuid}/command/specific/start_offline_session`, {
      method: 'POST',
      headers: {
        ...TwoAAClient.baseHeaders,
        Authorization: `Bearer ${this.access?.accessToken}`,
      },
      body: JSON.stringify({
        timestamp: (Date.now() + 60 * 60 * 24) / 1000,
        allowedCommands: ['start', 'stop'],
      }),
    });

    const data = (await response.json()) as Response<StartOfflineSessionResponse>;

    if ('success' in data) {
      return data;
    } else {
      throw data;
    }
  }

  static async endOfflineSession(uuid: string, sessionId: number, history: string[]): Promise<ResponseBody<null>> {
    if (!this.isValid) {
      throw 'auth not set';
    }

    const response = await fetch(`${TwoAAClient.baseUrl}/vehicle/${uuid}/command/specific/end_offline_session`, {
      method: 'POST',
      headers: {
        ...TwoAAClient.baseHeaders,
        Authorization: `Bearer ${this.access?.accessToken}`,
      },
      body: JSON.stringify({
        sessionId,
        history,
      }),
    });

    const data = (await response.json()) as Response<null>;

    if ('success' in data) {
      return data;
    } else {
      throw data;
    }
  }
}
