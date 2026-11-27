# ODMS Mobile

**Request monitoring, track progress, and review results from your phone.**

ODMS Mobile is the Flutter client for the **On-Demand Monitoring System**. It connects to the same ODMS backend as the web app and adapts Customer and Staff workflows for Android and iOS.

## Features

| Role | Workflows |
| --- | --- |
| **Customer** | Submit a monitoring request in six steps, select the coverage area on a map in step 2, track order progress, review quotes and delivered results, browse photos and videos, and get help through the FAQ and support. |
| **Staff** | View assigned missions and maintain permitted records for checklists, evidence, availability, and related work. Flight controls are outside the mobile Staff workspace. |

**AI Change Analysis** is available in the Customer media library. Customers can select two images, submit an analysis request, and view job history. The backend image-processing worker must be configured to produce new results.

## Tech Stack

| Area | Technology |
| --- | --- |
| App | Flutter 3.51.0-0.2.pre and Dart with SDK constraint `^3.14.0` |
| UI | Material 3 widgets, Be Vietnam Pro, light and dark themes |
| State and routing | Riverpod and GoRouter |
| API and authentication | Dio, Flutter Secure Storage, and Cognito for Google sign-in |
| Maps | flutter_map and latlong2 |
| Tests | Dart unit tests, Flutter widget tests, and opt-in backend smoke tests |

## Getting Started

### 1. Prepare your environment

Install the Flutter version listed above. For Android, install the Android SDK and JDK 21. For iOS, use macOS with Xcode. Start the ODMS backend and have a valid Customer or Staff account available.

### 2. Configure the API

```bash
flutter pub get
cp config/development.example.json config/development.json
```

Set `API_BASE_URL` in `config/development.json` for the device you are using.

| Target | Example |
| --- | --- |
| Android emulator | `http://10.0.2.2:8080` |
| iOS Simulator | `http://localhost:8080` |
| Physical device | An address reachable from the device, such as `http://192.168.1.10:8080` |
| Release | An HTTPS endpoint, using the [production configuration template](config/production.example.json) |

For local HTTP development, set `auth.refresh-token-cookie.secure=false` on the development backend so the refresh cookie can be used. Use HTTPS and secure cookies in production. Keep local configuration, credentials, and signing keys outside Git.

For Google sign-in, set `COGNITO_DOMAIN` and `COGNITO_CLIENT_ID` and register the configured `OAUTH_REDIRECT_URI` in Cognito. The template uses `odms://auth/callback`.

### 3. Run the app

```bash
flutter devices
flutter run --dart-define-from-file=config/development.json
```

To reach a backend running on your computer at port `18080` from an ADB-connected Android device:

```bash
adb reverse tcp:18080 tcp:18080
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:18080
```

## Project Structure

| Path | Responsibility |
| --- | --- |
| `lib/app/` | Application setup, routes, and theme |
| `lib/core/` | API client, configuration, common providers, models, and mobile role policies |
| `lib/features/` | Screens, components, and workflows grouped by feature |
| `lib/shared/` | Reusable controls, forms, map widgets, navigation, and localization helpers |
| `assets/` | Product imagery, logos, and fonts |
| `config/` | Example development and release configuration |
| `test/` | Unit tests, widget tests, and backend smoke tests |

Keep screen entry points focused on loading data, composing components, and navigation. Put feature-specific widgets next to the screen that uses them. For example, [Customer order details](lib/features/customer/order_detail.dart) delegates the order workspace, summary, coverage map, and reports to separate files. Put widgets used by several domains in `lib/shared/` and shared network or permission policy in `lib/core/`.

## Design Guide

ODMS uses a blue accent, restrained borders, clean typography, and imagery tied to the monitoring service or task. Start with the [app theme](lib/app/theme.dart) and [shared UI components](lib/shared/mobile_ui.dart) when building a page.

### Color and type

| Token | Light theme | Dark theme | Use |
| --- | --- | --- | --- |
| Primary | `#1565E8` | `#1565E8` | Primary actions, focus, and selected navigation |
| Canvas | `#F4F7FC` | `#0B1226` | Screen background |
| Surface | `#FFFFFF` | `#111B36` | Cards, inputs, and navigation |
| Text | `#0F1B3D` | `#E6ECFA` | Headings and primary content |
| Secondary text | `#64748B` | `#93A1C0` | Supporting text and metadata |
| Border | `#E6ECF5` | `#1F2C4D` | Dividers and outlines |

Use the Be Vietnam Pro styles from `Theme.of(context).textTheme`. Screen headlines use 21 to 28 logical pixels and bold weight. Body styles use 12 to 14 logical pixels. Read colors from the theme so components adapt to both modes.

### Layout and interaction

| Element | Pattern |
| --- | --- |
| Page hierarchy | Lead with the current task, the primary action, and the status. Group supporting information below it. |
| Cards and spacing | Use `SectionCard` for related information. Its default padding and corner radius are 16 logical pixels. Use a flat list where rows belong to the same group. |
| Actions and forms | Use a filled button for the primary action and outlined buttons for secondary actions. Theme buttons and inputs use 12-pixel corners. Keep form labels visible and place validation feedback by the corresponding field. |
| Maps and media | Show the selected coverage and the order's own images when available. Keep map attribution visible and show a clear placeholder when media is unavailable. |
| Status and feedback | Pair status color with a readable label. Include loading, empty, and retry states on screens that fetch data. |
| Motion | Use short transitions to show a change in state. Order detail tabs use a 180 ms transition and respect the system's reduced-motion preference. |

Keep the six-step request flow aligned with the web workflow, with the map in step 2. Check new screens at phone width in both themes and in both supported app languages, English and Vietnamese.

## Verification and Builds

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --concurrency=1
```

For smoke tests, set `ODMS_SMOKE_BASE_URL` and `ODMS_SMOKE_PASSWORD` in your environment. Use an isolated test database because the suite creates a Customer order and exercises Staff availability CRUD. The Staff smoke test removes its temporary availability entry.

```bash
flutter test test/live_order_smoke_test.dart
```

Build an Android debug APK or an unsigned iOS build:

```bash
flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=config/development.json
flutter build ios --no-codesign --dart-define-from-file=config/development.json
```

To export UI previews with test fixtures into `build/previews/`:

```bash
flutter test test/redesign_test.dart --concurrency=1 --dart-define=EXPORT_PREVIEWS=true
```

See [Feature coverage](docs/features.md), [Architecture](docs/architecture.md), and [Verification notes](docs/verification.md) for more detail.

## Workflow and Contributing

### Branch naming

Start from the latest `dev` and use `type/description-slug`. Write the slug in lowercase English with hyphens between words.

| Type | Use | Example |
| --- | --- | --- |
| `feat` | Add a user-facing capability | `feat/customer-gallery-filters` |
| `fix` | Correct a bug | `fix/staff-availability-validation` |
| `design` | Update layout, styling, or interaction | `design/order-detail-header` |
| `refactor` | Restructure code while preserving behavior | `refactor/split-mission-components` |
| `chore` | Maintain tooling, dependencies, or build configuration | `chore/update-flutter-sdk` |
| `docs` | Update documentation | `docs/update-mobile-readme` |
| `test` | Add or improve automated coverage | `test/customer-order-flow` |

### Commit messages

Use `type(scope): description` for feature changes or `type: description` for project-wide changes. Start the lowercase description with an imperative verb, omit the final period, and keep the commit focused on one feature or related change.

```text
feat(customer): add gallery filters
fix(staff): validate availability dates
refactor(ui): extract order status badge
chore: update flutter sdk
```

### Pull requests

1. Create a working branch from the latest `dev`.
2. Run the formatter, analyzer, and relevant tests. Check UI changes on a phone or emulator.
3. Commit changes by feature and push the working branch.
4. Open a PR targeting `dev`. Explain the change, list the checks you ran, and attach screenshots for UI changes.
5. Request review and merge approved changes into `dev`. Promote reviewed versions to `main`.

```bash
git switch dev
git switch -c feat/customer-gallery-filters
# After editing and verification
git add lib/features/customer/
git commit -m "feat(customer): add gallery filters"
git push -u origin feat/customer-gallery-filters
```
