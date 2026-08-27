# Rapidcare

Rapidcare is a healthcare and emergency-response platform designed for rapid medical dispatch, responder coordination, patient management, and live operational visibility.

## Architecture
- Backend: Flask + SQLAlchemy + JWT auth in `rapidcare_backend/`
- Frontend: Flutter app in `rapidcare_app/`
- Local database: SQLite at `instance/rapidcare.db`
- Production override: MySQL via environment variables (`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`)

## Quick Start
1. Create and activate a Python virtual environment.
2. Install dependencies from `rapidcare_backend/requirements.txt`.
3. Set `JWT_SECRET_KEY` in your environment if running outside tests.
4. Start the API using `python rapidcare_backend/app.py`.

The application will automatically create the `instance/` folder if it does not exist and will default to SQLite when MySQL credentials are not provided.
