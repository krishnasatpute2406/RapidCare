# Rapidcare Backend (expanded)

This service provides the backend API for the Rapidcare mobile application.

## Endpoints

- `GET /` — service status
- `GET /health` — (inherited) service health status
- `POST /register` — create a test user (email, full_name, password)
- `POST /login` — user authentication (email, password)

Bed allocation
- `POST /api/hospitals/<hospital_id>/allocate-bed` — allocate a general or ICU bed for the authenticated patient
	- JSON body: `{"bed_type": "general", "emergency_request_id": "ER-123"}`
	- Returns `201` for a new allocation, `200` for an idempotent retry, `404` when inventory is missing, or `409` when no bed is available.

## Quick start

```bash
cd rapidcare_backend
python -m venv .venv
# Windows
.venv\Scripts\activate
pip install -r requirements.txt
set JWT_SECRET_KEY=change-me-in-production
python -m rapidcare_backend.app
```

## Notes

- The service uses SQLite at `sqlite:///rapidcare.db` for local development.
- Set `JWT_SECRET_KEY` in the environment before starting the service.
