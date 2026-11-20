# Functional coverage

This is a working initial mobile implementation of the main workflows, not a certification of complete website parity. Live acceptance against the configured backend is still required.

| Area | Implemented mobile behavior |
| --- | --- |
| Authentication | Login, remembered session, OTP registration/verification/resend, password recovery/reset, first-login password change, Google callback, profile edit/logout |
| Customer orders | Counts and filters, requests, service/time-slot/deliverable selection, polygon area, recurrence, contact/access, authorization/permit documents, formats, retention/terms, pending edits and requested corrections |
| Customer checklist | Catalogue/custom requirements, requested media counts, mandatory-item preservation, revision-aware updates |
| Customer results | Mission reports, checklist observations, delivery review, acceptance and revision request |
| Customer finance | Quote acceptance, contract download/signed PDF upload, deposit/milestone payment initiation, server payment-result refresh, cancellation/refund status and receipts |
| Customer media | Available assets, fresh viewing/original-download URLs; monitoring hub lists in-progress orders, matching the website's current API |
| Manager overview | Date range, order/mission/pricing statistics, action items, recent orders/activity and distribution summaries |
| Manager orders | Review/approval/rejection/info requests, area/permit review, quote/checklist guidance/pricing, contracts and cancellation decisions |
| Manager planning | Mission creation, checklist allocation, execution plan finalization/amendment, crew/device assignment/removal, schedule changes, permit updates and permitted cancellations |
| Manager delivery | Media/report approval/rejection, result bundle selection/publication, revision decisions and rework mission creation/finalization |
| Manager resources | Paginated device catalogue and manager create/update/delete; maintenance assignment and payment allocation |
| Staff | Assigned missions and response, weekly busy-session CRUD, monitoring checklist execution/assessment, evidence attach/detach, report submission, native evidence upload, qualifications/documents and assigned maintenance resolution |
| Shared | Support conversations/status, notification feed, profile, language/theme and role-isolated navigation |

## Deliberately excluded

ADMIN portal; staff drone pairing/connection, handover, preflight, flight commands and postflight. Existing React Native dairy-farm source is untouched.

## Remaining website details

Advanced geospatial file import and weather/airspace advisory panels; manager AI resource recommendations and resource replacement workflows; complete versioned delivery draft/replacement/surplus flows; dedicated manual-upload-task recovery UI; support FAQ/analytics and notification background push are not implemented. Phone layouts for the primary role screens have widget coverage; every backend lifecycle branch has not been exercised on devices.

The backend is authoritative. Error states are shown for unsupported lifecycle transitions rather than bypassing server rules or substituting demo success. Runtime data is real API data; fixtures are used only in tests/previews.
