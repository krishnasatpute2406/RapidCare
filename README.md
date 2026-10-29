# RapidCare setup and shared demo deployment

RapidCare consists of a Flask API (`app.py`), a Flutter Android app (`rapidcare_k/`), an administrator/hospital portal, and a database. Patient emergency access remains available without a patient account or login. Local development defaults to SQLite; a public QR release must be built against one shared HTTPS API backed by persistent PostgreSQL.

## Local backend setup on Windows

Use Python 3.13 or another compatible Python 3 release. From this project directory, create a virtual environment and install the pinned dependencies:

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

For development on a trusted private Wi-Fi network, set Flask to listen on the computer's network interfaces and configure a local demo password before starting it:

```powershell
$env:RAPIDCARE_HOST = "0.0.0.0"
$env:RAPIDCARE_DEMO_PASSWORD = "replace-with-a-strong-demo-password"
.\.venv\Scripts\python.exe app.py
```

Flask listens on port `5000`. In local development, the default database URI is `sqlite:///rapidcare.malad-goregaon.demo.db`. The app creates its tables and seed records on startup. Do not delete, rename, overwrite, or point tests at existing SQLite databases or backups. Tests use an in-memory SQLite database.

## Run on a physical Android phone over private Wi-Fi

1. Connect the phone and development computer to the same trusted private Wi-Fi network.
2. Run `ipconfig` and note the IPv4 address for the active Wi-Fi adapter (not `127.0.0.1`).
3. If Windows Firewall blocks the phone, allow inbound TCP port `5000` for the **Private** network profile only.
4. From `rapidcare_k/`, run:

```powershell
flutter run --dart-define=API_BASE=http://<COMPUTER-WIFI-IP>:5000
```

Replace `<COMPUTER-WIFI-IP>` with the address from step 2 and keep Flask running. Allow location while the app is in use and enable Location Services. Approximate fixes are accepted and their accuracy is shown; confirm the pickup pin on the emergency map. HTTP is enabled only for Android debug builds; the release manifest blocks cleartext HTTP.

## Shared QR demo deployment (not deployed yet)

The files are prepared for a no-cost demo using a Render Free web service and Neon Free PostgreSQL. No hosting account, cloud resource, public GitHub repository, public APK, or QR destination has been created or published. Deployment and QR generation remain pending account connection, repository visibility choice, and selection of a stable HTTPS APK download/landing-page URL.

1. Create a Neon Free PostgreSQL project. Copy its connection string and keep it private. The backend accepts `postgresql://`/`postgres://` URLs and converts them to the Psycopg driver form. Keep the provider's TLS requirement (normally `sslmode=require`). Do not copy a database URL into source code, this README, the APK, or a QR code.
2. Connect this repository to Render only after choosing whether the GitHub repository is private or public. Use the prepared [`render.yaml`](render.yaml) Blueprint. It declares a Free web service and does not create a separate Render database.
3. Set `RAPIDCARE_DATABASE_URI` to the Neon connection string and `RAPIDCARE_DEMO_PASSWORD` to a private password of at least 12 characters in the Render service environment. The Blueprint generates `RAPIDCARE_SECRET`. Do not add payment details or select a billable plan. Production refuses to start with missing secrets or a local SQLite URL.
4. After deployment, verify `https://<render-service>.onrender.com/healthz` returns `{"status":"ok"}`. The live hosted database is separate from existing local SQLite files; this setup does not automatically migrate local records.
5. Sign in to the admin portal at the service root with username `admin` and the configured demo password. In **Hospital Network Directory**, edit General Beds and ICU Beds for any facility and select **Save beds**. The existing hospital-staff portal can also update its assigned hospital. These values are written to the shared database.
6. Build the phone release with the same HTTPS API URL:

```powershell
cd .\rapidcare_k
flutter build apk --release --dart-define=API_BASE=https://<render-service>.onrender.com
```

7. Host that APK at the stable HTTPS download/landing page you choose, then make the QR code point to that page. Each QR user must install the same release build so all phones call the same API. The QR is a download link, not a database credential. Do not create a public QR until the hosting URL and sharing permissions are approved.

The patient hospital list polls the shared API every 10 seconds while open. The administrator can update capacity without adding a login step to the patient emergency flow. If Render's free service has been idle, its first request may take around a minute to wake; Neon Free can also scale down when idle. Do not use this free demo for real emergency response or real patient data. Bed counts and recommendation data are unverified directory/demo values; call hospitals to confirm. For an actual emergency, use the local emergency number (108 in this region).

## Run local checks safely

Backend API tests run against in-memory SQLite and do not write to existing project databases:

```powershell
py -3.13 .\tests\test_emergency_tracking.py
```

Flutter checks from `rapidcare_k/`:

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

The current widget test passes. The analyzer still reports pre-existing warnings and lint information in other screens; see the task notes for the baseline comparison. A phone must appear in `adb devices -l` before install or live GPS behavior can be verified on-device.
