# Rapidcare Updated SRS

## 1. Product Overview
Rapidcare is a healthcare and emergency-response platform focused on quick medical dispatch, patient management, responder coordination, dispatch visibility, and real-time operational alerts. The system is designed to support patient-facing workflows, responder operations, and hospital coordination through a modular API and a mobile-friendly client experience.

## 2. Architecture Summary
The project is structured as a monorepo containing:

- `rapidcare_backend/`: Flask backend service for API and data-layer logic
- `rapidcare_app/`: Flutter-based client application
- `instance/`: local runtime storage directory for SQLite development data
- `SRS/`: product and requirements artifacts
- Root-level docs such as `README.md` and `Updated_SRS.md`

The backend is implemented as a Flask application factory using SQLAlchemy and Flask-JWT-Extended. This keeps the service modular, testable, and ready for expansion into richer role-based modules such as dispatch, hospitals, ambulances, and alerts.

## 3. Environment and Database Strategy
Rapidcare supports both local development and production deployment:

- Default local development database: SQLite at `instance/rapidcare.db`
- Production override: MySQL connection via environment variables (`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`)
- Default local configuration is intentionally non-destructive and safe for developers without external database credentials.

This dual-database design preserves developer convenience while keeping the backend compatible with a production MySQL deployment.

## 4. Current Backend Model Layer
The primary persistence model is defined in `rapidcare_backend/models.py`.

### User model
- `User`
  - `id`: primary key
  - `name`: full display name
  - `email`: unique email identifier, normalized to lowercase
  - `phone`: contact number
  - `password_hash`: securely hashed password using bcrypt
  - `role`: enum-based role (`patient`, `driver`, `hospital`, `admin`)
  - `created_at`: timestamp for record creation

The `User` model includes validation hooks for email normalization and role enforcement, and helper methods for hashing and checking passwords.

## 5. API and Blueprint Layout
The backend exposes API modules under `rapidcare_backend/api/`.

Current blueprint structure:

- `rapidcare_backend/api/auth.py`
  - URL prefix: `/api/auth`
  - Endpoints include registration, login, "me", and role-protected admin routes
- `rapidcare_backend/api/ambulance.py`
  - reserved for ambulance operations and tracking
- `rapidcare_backend/api/hospitals.py`
  - reserved for hospital and emergency coordination logic
- `rapidcare_backend/api/decorators.py`
  - shared role/auth guards for protected routes

The application bootstrap in `rapidcare_backend/__init__.py` registers the auth blueprint and exposes health and root service endpoints.

## 6. Security Assumptions
- Credentials are never stored in source code
- Passwords are hashed with bcrypt before persistence
- JWT secret keys should be supplied through environment configuration in non-test deploys
- Local SQLite files are stored under the `instance/` directory and are excluded from Git tracking by `.gitignore`

## 7. Planned Expansion
The current backend is a solid starting point for additional modules such as:

- emergency dispatch workflows
- responder availability and location tracking
- hospital allocation and patient assignment
- audit logs and alert escalation
- notification events for real-time client updates

This SRS reflects the current state of the project and should be updated as new backend modules and mobile workflows are implemented.
