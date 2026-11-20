# Architecture

## Source contracts

The React `ondemand-monitoring-web` checkout supplies the workflows and vocabulary. Spring controllers, DTOs and services in `on-demand-monitoring-system/ondemandmonitoring` are the authority for wire contracts and permissions. Existing website comments marked PROPOSED were checked against controller source; several are stale. No backend source was modified by this task.

The CodeGraph MCP tools were unavailable. Analysis used source, API consumers, DTOs and tests instead.

## Layers

- `app`: GoRouter, role routing and Material theme.
- `core`: Dio transport, API envelopes/errors, secure secrets, settings and mobile route policy.
- `shared`: reusable native forms, cards, status labels, area selection, files and role navigation.
- `features`: role workflows and their screen state. Riverpod supplies the API/session; local view state holds filters, selections and edit progress.

## Authentication

Access tokens are memory-only. Refresh and CSRF cookies use the existing backend contract; remembered cookies are encrypted with platform secure storage. Refreshes are coalesced, expired access requests retry once, and stale responses cannot restore a logged-out session. Temporary network failures preserve saved sessions. ADMIN and unknown roles are rejected. Account switches change the session revision and discard prior routed state.

## Evidence

Files are hashed as streams, then transferred directly to backend-issued HTTPS storage URLs. Storage requests use a separate Dio client with no ODMS bearer token/cookie. PUT and multipart uploads are supported. Capture time and provenance are entered explicitly. Failure events remain encrypted for replay by the same user. Backend policy continues to decide capture-state eligibility, evidence validity, review and publication.

## Mobile presentation

Native Flutter widgets, not an HTML wrapper. Website logo, font, blue palette and business labels remain; phone layouts use bottom navigation, compact statistics, searchable cards and role-specific landing pages. Light/dark themes and Vietnamese/English are supported.
