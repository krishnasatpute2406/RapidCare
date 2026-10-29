# RapidCare Local Implementation Plan

## Scope and fixed constraints

- Continue plain-local development in the existing project: `app.py` is the Flask backend and `rapidcare_k/` is the Flutter Android app.
- Launch to the RapidCare splash screen and then the patient home in Guest mode. Patient sign-in/registration is optional and reachable only when a patient opens Profile; never insert it into the emergency sequence. Keep the driver portal separate from patient access.
- Preserve the emergency sequence: location → emergency type → hospital selection → patient details → assigned emergency. Preserve the current red emergency identity and teal/green ordinary-screen palette; make the style cohesive using RapidCare's own visual language, without copying ReadAura's fonts, palette, shapes, wording, or layouts.
- Keep the existing SQLite data files and historical backups untouched during implementation and testing. Schema changes, if required, must be additive/migratable and validated against a disposable test database before any live/local data is migrated.
- The project now includes a shared public demo deployment: one hosted Flask API backed by persistent PostgreSQL, so authorized hospital bed/capacity changes are stored once and returned to all patient app instances using the same QR. Do not add a login gate to patient emergency access.
- Use the researched no-cost demo topology (Render Free web service + Neon Free PostgreSQL); do not use Render Free Postgres because it expires after 30 days. Do not create billable resources, add payment details, or publish the repository without explicit user confirmation. Explain free-tier cold starts and limits.
- Keep existing local SQLite files and backups untouched; do not automatically migrate local data to the cloud. Production secrets stay in hosting environment variables, never in Git or the QR. The public Flutter build must use the deployed HTTPS API URL. Local private-Wi-Fi development remains available.

## Implementation approach

### 1. Establish a working, repeatable local baseline

- Verify Flutter/Dart and Python runtimes and why the current Flutter version command is slow or blocked before running builds or installing anything.
- Identify the active backend dependency manifest (the project root now uses `requirements.txt`) and document reproducible local and hosted startup paths without exposing secrets.
- Confirm the active Flutter entry point, API base URL configuration, Android permissions, and backend bind address/firewall requirements for a physical phone.
- Preserve the clean Git starting state; use a dedicated disposable SQLite test database for tests.

### 2. Make hospital recommendations coherent and explainable

- Keep recommendation ranking authoritative on the backend; remove or avoid conflicting client-side re-ranking once behavior is verified.
- Define requirements per emergency type using the existing specialist/service data, distinguish unknown/unrecorded from unavailable, and show the matching and missing/unknown capabilities.
- Keep capability fit ahead of proximity, then improve proximity with road travel-time estimates when available and clearly label fallback straight-line distance/rough ETA.
- Include data freshness/verification for emergency acceptance, beds/ICU capacity, coordinates, and operational status; never represent stale or unknown values as confirmed.
- Provide safe, explicit fallbacks when location, routing, hospital data, or a complete capability match is unavailable; retain the 108 fallback and allow the patient to continue without account creation.
- Do not present the ranking as clinical advice or guarantee that a facility will accept a patient.

### 3. Make patient and driver maps reliable and role-specific

- Trace and stabilize the existing driver GPS → backend ambulance record → assigned emergency → patient/driver map data path.
- Use the backend's assigned emergency and latest ambulance GPS as the shared source of truth. Enforce each driver's assigned-ambulance authorization and the patient's single-emergency token scope.
- Patient perspective: pickup, assigned ambulance, progress/status, and an honest ETA/freshness indication.
- Driver perspective: driver/ambulance position, route toward the pickup, pickup marker, and destination/hospital when appropriate; preserve shared case identity and status while framing and controls differ by role.
- Handle loading, permission denied, GPS stale/offline, no network, route-service unavailable, and missing coordinates without showing a stale marker as live.
- Provide a deterministic, clearly labeled judge/demo scenario only if it can be isolated from real dispatch and does not change the normal emergency flow.

### 4. Strengthen driver account lifecycle

- Replace immediate public driver activation with a pending access request and an explicit authorized approval step; pending drivers must not log in, go online, publish location, or receive a case.
- Keep approved-driver sign-in professional and simple: phone number and PIN only for the current demo, separate from patient access; sign-in alone does not mark a driver Available. Avoid unnecessary onboarding and login steps while retaining failed-login protection and an eventual PIN-reset path.
- Add a server-side way to revoke/suspend driver sessions when an account is disabled; maintain authorization checks for ambulance, location, status, and case endpoints.
- Use additive SQLite migration(s), preserving existing approved driver records and hashes; test on a disposable database before touching any project instance database.

### 5. Unify Flutter UI without changing emergency identity

- Inventory the authored Flutter screens and define a shared theme/tokens for typography, spacing, surfaces, card shapes, field/button sizing, and common loading/empty/error states.
- Introduce reusable widgets for shared controls and status presentation; update screens in small batches, beginning with driver login/registration and the emergency hospital/assigned-map surfaces.
- Keep the current teal/green styling on ordinary patient and driver screens and red styling for the emergency flow; use restrained, original RapidCare decorations, high contrast, readable text, and accessible tap targets.
- The splash leads directly to the patient home as Guest. Optional patient sign-in/register is available from Profile only; emergency access remains account-free and no authentication page is inserted into the emergency sequence.

### 6. Physical Android device development connectivity

- Configure the Flutter app for a user-supplied `API_BASE` pointing to the development computer's private Wi-Fi IPv4 address; retain emulator and local development behavior.
- Ensure Flask listens on the appropriate private interface and document the minimal private-network firewall allowance, location permission, and startup sequence.
- Clearly distinguish the HTTP development setup from production security; do not treat private-Wi-Fi HTTP as safe for public deployment or sensitive production use.

### 7. Shared QR-based demo deployment and live bed data

- Configure the hosted Flask process to require a persistent PostgreSQL URL and explicit secrets in production; normalize provider URLs for Psycopg and fail closed instead of falling back to local SQLite.
- Use the Render Free Blueprint and Neon Free PostgreSQL connection string only after the user connects those services; do not create paid resources, enter payment details, or publish the repository without explicit authorization.
- Let administrators edit general and ICU bed counts for any hospital in the existing admin portal; validate whole, non-negative values on both client and server. Hospital staff retain their existing assigned-hospital update path.
- Save hospital capacity to the single shared database and have the patient hospital/recommendation feed read those same records without patient login. The active hospital list refreshes every 10 seconds.
- Restrict Android cleartext HTTP to debug builds; build QR-distributed release APKs only with the deployed HTTPS API URL supplied through `API_BASE`.
- Generate/distribute a QR code only after the user selects an approved app-download/landing-page destination. The QR must contain no credentials and must resolve to a release connected to the shared API.
- Use demo/synthetic records only. Clearly disclose the free service's cold-start and quota limits; do not represent the project as a production emergency-response service or confirmed clinical bed feed.

## Project structure and responsibilities

- `app.py`: Flask API, authentication/authorization, recommendation ranking, emergency lifecycle, live ambulance state, and database models/migration-safe changes.
- `rapidcare_k/lib/services/api.dart`: shared API base URL and authenticated request handling.
- `rapidcare_k/lib/screens/patient/emergency/`: existing patient emergency steps; preserve sequence and red styling while improving hospital recommendations and assigned-map reliability.
- `rapidcare_k/lib/screens/driver/`: driver login/registration, driver dashboard, GPS update and role-specific map view.
- `rapidcare_k/lib/theme/` and `rapidcare_k/lib/widgets/` (only if justified by current layout): shared design tokens/theme and reusable UI components.
- `rapidcare_k/android/`: Android permissions and platform configuration required for GPS, networking, maps, and dialer.
- `render.yaml`: no-cost Render service blueprint with runtime-only database and demo-password secrets.
- `implementation-plan.md`: this agreed scope and design/architecture plan.

## Current execution constraints and verification

- Python 3.13.9 is available through the Windows `py` launcher; the Flutter SDK is installed under `C:\Developer\flutter`. Direct cached Dart/Flutter tool invocation is used because the wrapper/version check initially exceeded the bounded command window.
- Backend tests use an in-memory SQLite database. Flutter analysis/widget tests use the installed SDK and do not require a connected phone.
- No Android device was connected at the last `adb devices` check, so installation and live GPS behavior on the user's phone remain unverified until a device is connected.
- Public hosting, a final public APK, and the QR download destination remain pending the user's GitHub visibility and hosting-account connection choices. No external account/resource has been created and no project source has been published.
