# Ionic Cordova example

This is an example project using Ionic + Cordova with Angular 13.
See [home.module.ts](src/app/home/home.module.ts) for the main functionality.

## Installation

```bash
    npm install
```

### Android

```bash
    ionic cordova prepare android
    ionic cordova run android --livereload --consolelogs
```

### Using iOS

```bash
    ionic cordova prepare ios
    ionic cordova run ios --livereload --consolelogs
```

### Link local plugin

During development it may be useful to link the local plugin

```bash
    cordova plugin add ../../packages/cordova-plugin-bleintsdk --link
```
