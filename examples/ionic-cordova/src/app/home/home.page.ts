import type {
  CommandResponse,
  CommandType,
  Commands,
} from '@2hire/bleintsdk-types';
import { Component } from '@angular/core';
import { AlertController, LoadingController } from '@ionic/angular';

const commands: Commands = {
  start:
    // eslint-disable-next-line max-len
    'ADGU7JYtAr5KKbrF5yYvC8BywtDPJEbXn8jdelmxUUKU0Ajy5MlOnoZqIU96nnrGJzj/vZl61HCs683roIusJ/GQK3JJ8XEHKfj7DJBFR0Vl1cpTyOOTZihZUTwlpXn+Vf0zLLJFfR5RCAwSkQ3/meTSIah1e7PmZljmzDa8q6wbwXBSJLhOhZTfMX4O8NXCkZPRTCuxu+tmEbIwdu9dv6w=',
  // eslint-disable-next-line max-len
  stop: 'Ab644CTCZPheMLWoprChjMpr3J1hjY9E0vjIfyERlDhtyji3hNAlxInyTNpTY7Tgf3X7IDy0hLzq5hstPJ4ZkzqlMSWOkQf6n6mmY7Hqu52omjNokGfUPAs3fsXxJDhBOoJIkVWW5WbQ3YFWvhknwJMDd6o1qp+Zb2wKV+KvzdsuTpAhLv5cXZVP3gNnHQxfOVvyF0MwLw80EQU+I++ojMk=',
  locate: '',
  // eslint-disable-next-line max-len
  noop: 'Apb9uzl903W403z9ZxO/tPaJ4otMtv93icRIh7IUhhowUH2+oMUGCxk/OoI7I5G6RCS+5lY/iPpfx1prdJdQYf57AVPNUjapbMVayMMkMyqzuJevGJBFmVUT1twoQpgRNasnDqvSwXbUCsoZ6fPQLz2v93rnXRqhbPzAJmLj1RZ8h5rwcDKOZpF0NTxdg4payvRHiaxurWHne2knNLYeoQU=',
  // eslint-disable-next-line @typescript-eslint/naming-convention
  end_session:
    // eslint-disable-next-line max-len
    '/4sBEgY0S18Pj1Hdc2vPQypG5grjw3dGAq9iEgzsvhpc2Ze61E3iEXQNnjJBD4k5VU1U2mQUuKTdXt8rrdEhQ7XEOgmUVOGWzl8ppfgEYsogzhst+3JDjeTLJWZl0BE/t6FiKSW26iTHZDQfNJ3LDjNSIUgNDMoTsKSJlm2NsR8f/L5T+XyCIzkIr5tZOvCJaU2O7YOpwzz/w4inaGsmWIQ=',
};

const publicKey = 'Az8OqWnCYYyKCmuAJYrKUXDryu1HjpowPoRB8JkD5RRe';

@Component({
  selector: 'app-home',
  templateUrl: 'home.page.html',
  styleUrls: ['home.page.scss'],
})
export class HomePage {
  accessToken = '';
  reports = Array<string>();
  sessionId: number | null = null;
  identifier = 'C6F59B130C7C';

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
