# ODMS Mobile

Flutter/Dart application for Android and iOS. Customer, staff and manager only.

## Setup

Use Flutter stable 3.50.1 / Dart 3.14 or compatible.

```sh
flutter pub get
cp config/development.example.json config/development.json
flutter run --dart-define-from-file=config/development.json
```

Configure API_BASE_URL for your device: Android emulator uses 10.0.2.2; iOS simulator uses localhost; physical devices need your server hostname/IP. Debug Android permits local HTTP. Release builds require HTTPS. Never commit local configuration or signing credentials.

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/development.json
flutter build ios --no-codesign --dart-define-from-file=config/production.json
```

iOS builds require full Xcode. Google sign-in requires the Cognito domain, client ID and an allowlisted odms://auth/callback redirect. This repository is local only.
