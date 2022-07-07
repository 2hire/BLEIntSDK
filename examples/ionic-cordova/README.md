# Ionic Cordova example

This is an example project using Ionic + Cordova with Angular 13.
See [home.module.ts](src/app/home/home.module.ts) for the main functionality.

## Getting Started

Example for using Android:

```bash
    npm install
    ionic cordova prepare android
    cordova plugin add ../../packages/cordova-plugin-bleintsdk --link
    ionic cordova run android --livereload --consolelogs
```

Example for using iOS:

```bash
    npm install
    ionic cordova prepare ios
    cordova plugin add ../../packages/cordova-plugin-bleintsdk --link
    ionic cordova run ios --livereload --consolelogs
```
