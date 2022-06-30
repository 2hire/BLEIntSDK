const path = require('path');
const pak = require('../../packages/react-native-bleintsdk/package.json');

module.exports = {
  presets: ['module:metro-react-native-babel-preset'],
  plugins: [
    [
      'module-resolver',
      {
        extensions: ['.tsx', '.ts', '.js', '.json'],
        alias: {
          [pak.name]: path.join(__dirname, '../../packages/react-native-bleintsdk', pak.source),
        },
      },
    ],
    [
      'module:react-native-dotenv',
      {
        moduleName: '@env',
      },
    ],
  ],
};
