# Verification

## Mobile workflow test cases

Run `flutter test --coverage` to execute the unit and widget suite and write an LCOV report to `coverage/lcov.info`. Widget tests render the Flutter screens and intercept Dio requests so they can verify controls, validation, payloads, and responses without external services.

| Workflow | Automated scenarios |
| --- | --- |
| Customer booking and order detail | All six steps, circle selection on the map, missing fields, required and inactive checklist items, success, HTTP 409 rejection, cancellation before submission, and retrying a failed order detail request |
| Scheduling and advisories | Reversed dates, early result deadline, missing recurrence count, weather/area/quote request contracts, incomplete location, and partial provider failure |
| Customer finance and delivery | Optional resources returning 404, quote acceptance, contract gate for deposit, result acceptance, revision eligibility, and review version sent to the API |
| Media, AI, and FAQ | Media type and search filtering, eligible photos, duplicate selection, worker unavailable with a retry using the same request key, pending and completed job handling, invalid result image data, FAQ filtering, and feedback retry |
| Staff | Availability create/update/delete, cancel delete, week navigation, failed load retry, mission evidence permission, checklist version and edit permission, qualification create/update, maintenance resolution, and excluded flight routes |
| Shared | Login validation and retry, Customer registration, OTP verification and resend, password reset, support ticket creation and reply, closed ticket state, Staff notification isolation, and role-specific profile updates |

Backend smoke tests are opt-in. Point `ODMS_SMOKE_BASE_URL` at an isolated backend and set `ODMS_SMOKE_PASSWORD` in the environment. See the [README](../README.md) for details. Device and service acceptance remains separate for Google sign-in, payment providers, native file selection and uploads, map tiles, and live AI inference.

## Initial implementation notes

- Flutter 3.50.1 / Dart 3.14.0 used during implementation.
- Android debug arm64 APK built successfully using JDK 21 and Android Build Tools 36. A final build is rerun after UI completion.
- Unit/widget suite covers API errors, CSRF refresh, concurrent refresh, logout races, unsupported roles, first-login challenge, GeoJSON shape, pagination, checklist serialization, staff route exclusions, upload checksums/credential isolation, role menus, and 360px role pages in light/dark mode.
- UI previews use synthetic test data. They do not establish live backend functionality.
- No live seeded-account acceptance run: the website is configured for localhost:8080, and no backend was listening there when checked. Credentials provided in chat were not saved in source or committed.
- iOS project generated, but iOS build was not run because full Xcode is unavailable; only Command Line Tools are selected.
- No remote, push, pull request, store publication, or backend edits.

The first Android build ran out of host disk space. Only task-generated disposable download/archive/documentation files were removed. A subsequent build succeeded after space became available.
