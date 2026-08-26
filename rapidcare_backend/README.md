# Rapidcare Backend (expanded)

This service provides the backend API for the Rapidcare mobile application.

## Endpoints

- `GET /` — service status
- `GET /health` — (inherited) service health status
- `POST /register` — create a test user (email, full_name, password)
- `POST /login` — user authentication (email, password)

Hospitals
- `GET /hospitals/` — list hospitals
- `GET /hospitals/<id>` — get hospital details

Ambulance
- `POST /ambulance/request` — request an ambulance (patient_name, pickup_address, severity)
- `GET /ambulance/requests` — list ambulance requests (admin/dev)

## Quick start

```bash
cd rapidcare_backend
python -m venv .venv
# Windows
.venv\Scripts\activate
pip install -r requirements.txt
set SECRET_KEY=change-me-in-production
python -m rapidcare_backend.app
```

## Notes

- This is a simple starter service using SQLite for local development.
- Use a proper production database and secret management in real deployments.
