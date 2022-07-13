import type {
  CommandResponse,
  CommandType,
  Commands,
} from '@2hire/bleintsdk-types';
import { Component } from '@angular/core';
import { AlertController, LoadingController } from '@ionic/angular';

const commands: Commands = {
  start: 'start_command_payload',
  stop: 'stop_command_payload',
  noop: 'noop_command_payload',
  end_session: 'end_session_command_payload',
};

const publicKey = 'public_key';

@Component({
  selector: 'app-home',
  templateUrl: 'home.page.html',
  styleUrls: ['home.page.scss'],
})
export class HomePage {
  accessToken = '';
  reports = Array<string>();
  sessionId: number | null = null;
  identifier = 'mac_address';

  constructor(
    public loadingController: LoadingController,
    public alertController: AlertController
  ) {}

  get plugin() {
    return cordova.plugins.BLEIntSDKCordova;
  }

  create = () =>
    this.handleAction(
      this.plugin.sessionSetup(this.accessToken, commands, publicKey)
    );

  startSequence = () => this.handleAction(this.plugin.connect(this.identifier));

  endSequence = () => this.handleAction(this.plugin.endSession());

  sendCommand = (command: CommandType) =>
    this.handleAction(this.plugin.sendCommand(command));

  private async handleAction(command: Promise<CommandResponse | boolean>) {
    const loading = await this.loadingController.create({
      message: 'Please wait...',
    });
    await loading.present();

    try {
      const response = await command;

      if (typeof response !== 'boolean' && response?.payload) {
        this.reports.push(response.payload);
      }

      await loading.dismiss();

      const alert = await this.alertController.create({
        header: 'Command Response',
        message: getCommandResponseDescription(response),
      });

      await alert.present();
    } catch (e) {
      await loading.dismiss();

      await showErrorAlert(e, this.alertController);
    }
  }
}

const getCommandResponseDescription = (res: CommandResponse | boolean) =>
  res === null
    ? 'Command response is null'
    : `Command was ${
        (typeof res === 'boolean' ? res : res.success)
          ? 'successful'
          : 'unsuccessful'
      }`.concat(
        typeof res !== 'boolean' ? ` with additional data: ${res.payload}` : ''
      );

const showErrorAlert = async (error: unknown, controller: AlertController) => {
  console.error(error);

  if (error instanceof Error) {
    const alert = await controller.create({
      header: 'An error occurred',
      message: error.message,
      buttons: [
        {
          text: 'Show More',
          handler: () => {
            alert.dismiss().then(async () => {
              const innerAlert = await controller.create({
                header: 'An error occurred',
                message: JSON.stringify(error),
              });

              await innerAlert.present();
            });
          },
        },
        { text: 'OK' },
      ],
    });

    await alert.present();
  } else {
    const alert = await controller.create({
      header: 'An error occurred',
      message: JSON.stringify(error),
    });

    await alert.present();
  }
};
