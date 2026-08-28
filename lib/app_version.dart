/// Keep in sync with the `version:` line in `pubspec.yaml` (`x.y.z+build`).
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');
const appBuild = String.fromEnvironment('APP_BUILD', defaultValue: '1');

String get appVersionLabel => 'v$appVersion';
