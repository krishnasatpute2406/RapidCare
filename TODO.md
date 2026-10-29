# RapidCare Implementation Outcomes

## Recommendation ranking and explanations
- The backend is the authoritative source for hospital ranking, and the Flutter client does not apply a conflicting ranking rule.
- Emergency-type requirements use the existing specialist/service data and distinguish unknown or unrecorded capability from a confirmed unavailable service.
- Recommendation results explain the matched, missing, or unknown capabilities, location/distance basis, ETA method, and data freshness without claiming clinical advice or guaranteed acceptance.
- Capability fit remains ahead of proximity; road travel time is preferred when available, with straight-line distance/rough ETA clearly identified as a fallback.
- Missing location, routing, hospital data, or complete capability matches have safe, clearly described fallback behavior; the emergency request remains available without patient login and the 108 option remains accessible.
- Stale or unknown acceptance, bed/capacity, location, or operational data is not presented as current/confirmed.

## Shared live emergency map, patient and driver perspectives
- Driver GPS updates, backend ambulance state, assigned emergency, and both map screens use the same active case and latest server-side location as their source of truth.
- The patient sees their pickup, assigned ambulance, emergency progress, and appropriately qualified ETA/location freshness.
- The assigned driver sees the same case identity/status with a driver-oriented perspective: ambulance location, route toward pickup, pickup marker, and destination/hospital when appropriate.
- Driver access is limited to that driver's authorized ambulance/case; the patient emergency token remains scoped to that one emergency.
- Loading, denied permissions, stale/offline GPS, network failure, missing coordinates, and route-service failure are communicated clearly; stale data is not styled as live.
- Any judge/demo simulation is clearly labeled, isolated from real dispatch, and does not alter the normal emergency flow.

## Driver verification and account lifecycle
- Public registration creates a pending access request instead of immediately activating a driver or issuing dispatch-capable access.
- Only an authorized administrator can approve/reject driver access after verification; pending drivers cannot sign in, go online, publish location, or receive cases.
- Approved-driver sign-in stays professional and simple: phone number and PIN only for the current demo, separate from patient access; sign-in alone does not mark a driver Available. Do not add unnecessary onboarding or extra login steps.
- PIN reset and failed-login protections are improved; disabled/suspended drivers can have active access revoked server-side.
- Existing approved driver identities and password hashes are preserved with additive SQLite migration behavior tested against a disposable database; existing instance databases and backups are not modified during development validation.

## Consistent Flutter interface with emergency design preserved
- App opens to the RapidCare splash screen then the patient home in Guest mode; patient emergency help is available without account creation or login.
- Patients may choose to sign in or register from Profile, but no login prompt interrupts the emergency flow; patient-account state stays separate from the emergency access token.
- Authored Flutter screens share consistent typography, spacing, controls, cards, and loading/empty/error patterns through reusable theme/components where appropriate. Keep RapidCare's present teal/green normal-screen colors and red emergency styling; use original, restrained design details rather than copying another app's theme/layout.
- Intentional red emergency-assistance styling remains red, accessible, high contrast, and visually prominent.
- Patient emergency flow remains location → emergency type → hospital selection → patient details → assigned emergency.
- Patient emergency request, tracking, and cancellation continue to use the emergency-specific token and remain isolated from optional patient accounts.

## Physical Android phone development connectivity
- The app can use a configured `API_BASE` for the development computer's private Wi-Fi IPv4 address while emulator/local defaults remain usable.
- Flask can be started on the appropriate private interface, with documented private-network firewall, location permission, and startup steps.
- Clearly distinguish the HTTP development setup from secure public/production transport; do not treat private-Wi-Fi HTTP as safe for public deployment or sensitive production use.

## Shared public QR service and live hospital capacity
- Every QR-installed phone build calls the same public HTTPS RapidCare API; patient emergency requests remain available without patient account creation or login.
- The hosted API uses persistent shared PostgreSQL, not an ephemeral/local SQLite file. Authorized hospital staff bed/capacity edits are written to that shared database, and patient hospital recommendations read the same records so changes are visible to other QR users on their next refresh.
- The admin hospital directory has editable General/ICU counts for any hospital, validated as whole non-negative values on both the client and server. An isolated integration test verifies that an anonymous second patient client reads the admin/staff update from the shared feed; the live screen refresh interval is 10 seconds.
- Do not alter existing local SQLite databases/backups or automatically migrate their records to the hosted database; any data migration requires a separate explicit approval and a verified backup.
- Keep all production credentials and database URLs out of source code, Git, public QR images, and documentation. Configure them as hosting environment secrets; production must fail closed if required secrets/database configuration is missing.
- Use only the researched no-cost demo tiers (Render Free web + Neon Free Postgres). Do not create billable resources, add payment details, or publish a public GitHub repository without explicit confirmation. Clearly disclose the Render cold start, Neon scale-to-zero, and free-tier usage/storage limits.
- The hosted dataset is demo/synthetic only. Do not present bed availability or recommendations as verified live clinical information or guaranteed hospital acceptance.

## Working baseline and project safety
- Flutter/Dart/Python runtime availability and any launch failure are diagnosed before builds or backend execution; no machine-level install/upgrade is made without the required explicit permission.
- A reproducible local backend startup/dependency path is documented without exposing secrets.
- The initial user project files and existing SQLite databases/backups are preserved; tests use a disposable database and the clean Git baseline is maintained.
