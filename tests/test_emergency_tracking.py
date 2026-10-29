import os
import sys
import unittest
from datetime import timedelta
from pathlib import Path
from sqlalchemy import create_engine, inspect

os.environ["RAPIDCARE_DATABASE_URI"] = "sqlite://"
os.environ["RAPIDCARE_DEMO_PASSWORD"] = "rapidcare-test-only-password"
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import (  # noqa: E402
    AmbulanceModel,
    EmergencyModel,
    HospitalModel,
    app,
    db,
    naive_now,
    migrate_driver_approval_schema,
    seed_all,
    resolve_database_uri,
)


class EmergencyTrackingApiTests(unittest.TestCase):
    def setUp(self):
        app.config["TESTING"] = True
        self.client = app.test_client()
        with app.app_context():
            db.session.remove()
            db.drop_all()
            db.create_all()
            seed_all()

    def test_production_database_requires_persistent_postgresql(self):
        with self.assertRaises(RuntimeError):
            resolve_database_uri(None, production=True)
        with self.assertRaises(RuntimeError):
            resolve_database_uri("sqlite:///rapidcare.db", production=True)
        self.assertEqual(
            resolve_database_uri("postgresql://demo:secret@db.example/rapidcare?sslmode=require", production=True),
            "postgresql+psycopg://demo:secret@db.example/rapidcare?sslmode=require",
        )
        self.assertEqual(resolve_database_uri(None), "sqlite:///rapidcare.malad-goregaon.demo.db")

    def _create_emergency(self):
        response = self.client.post(
            "/api/app/emergency",
            json={
                "lat": 19.17,
                "lng": 72.85,
                "emergency_type": "cardiac",
                "patient_name": "Test Patient",
                "patient_phone": "9876543210",
            },
        )
        self.assertEqual(response.status_code, 201, response.get_json())
        payload = response.get_json()
        return payload["emergency"]["id"], payload["access_token"]

    def test_emergency_can_start_and_be_tracked_without_patient_login(self):
        emergency_id, access_token = self._create_emergency()

        response = self.client.get(
            f"/api/app/emergency/{emergency_id}",
            headers={"Authorization": f"Bearer {access_token}"},
        )

        self.assertEqual(response.status_code, 200, response.get_json())
        self.assertEqual(response.get_json()["id"], emergency_id)

    def test_emergency_payload_reports_live_and_stale_driver_gps(self):
        emergency_id, access_token = self._create_emergency()
        with app.app_context():
            ambulance = AmbulanceModel(
                vehicle_number="TEST-AMB-001",
                driver="Test Driver",
                phone="9876543211",
                type="BLS (Basic Life Support)",
                status="Available",
                lat=19.171,
                lng=72.851,
                updated_at=naive_now(),
            )
            db.session.add(ambulance)
            db.session.flush()
            emergency = db.session.get(EmergencyModel, emergency_id)
            emergency.ambulance_id = ambulance.id
            db.session.commit()
            ambulance_id = ambulance.id

        headers = {"Authorization": f"Bearer {access_token}"}
        live = self.client.get(f"/api/app/emergency/{emergency_id}", headers=headers)
        ambulance_info = live.get_json()["ambulance_info"]
        self.assertTrue(ambulance_info["location_is_live"])
        self.assertIsInstance(ambulance_info["gps_age_seconds"], int)

        with app.app_context():
            ambulance = db.session.get(AmbulanceModel, ambulance_id)
            ambulance.updated_at = naive_now() - timedelta(minutes=2)
            db.session.commit()

        stale = self.client.get(f"/api/app/emergency/{emergency_id}", headers=headers)
        ambulance_info = stale.get_json()["ambulance_info"]
        self.assertFalse(ambulance_info["location_is_live"])
        self.assertGreaterEqual(ambulance_info["gps_age_seconds"], 120)

    def test_hospital_recommendations_are_ordered_by_capability_fit(self):
        response = self.client.get(
            "/api/app/hospitals?type=cardiac&lat=19.17&lng=72.85"
        )
        self.assertEqual(response.status_code, 200, response.get_json())
        matches = [item["capability_matches"] for item in response.get_json()]
        self.assertEqual(matches, sorted(matches, reverse=True))

    def test_existing_seed_backfills_pregnancy_and_burn_capabilities(self):
        with app.app_context():
            lifeline = HospitalModel.query.filter_by(
                name="Life Line Medicare Hospital Pvt Ltd"
            ).one()
            lifeline.obgyn = False
            lifeline.maternity_ot = False
            db.session.commit()

            # Simulate a previously populated database and rerun startup seeding.
            seed_all()
            self.assertTrue(lifeline.obgyn)
            self.assertTrue(lifeline.maternity_ot)
            burn_center = HospitalModel.query.filter_by(name="National Burns Center").one()
            self.assertTrue(burn_center.plastic_surgeon)
            self.assertTrue(burn_center.burn_unit)

        pregnancy = self.client.get(
            "/api/app/hospitals?type=pregnancy&lat=19.17&lng=72.85"
        )
        self.assertEqual(pregnancy.status_code, 200, pregnancy.get_json())
        self.assertEqual(pregnancy.get_json()[0]["name"], "Life Line Medicare Hospital Pvt Ltd")
        self.assertEqual(pregnancy.get_json()[0]["capability_matches"], 2)

        burn = self.client.get("/api/app/hospitals?type=burn&lat=19.17&lng=72.85")
        self.assertEqual(burn.status_code, 200, burn.get_json())
        self.assertEqual(burn.get_json()[0]["name"], "National Burns Center")
        self.assertEqual(burn.get_json()[0]["capability_matches"], 2)

    def test_driver_registration_is_pending_and_blocked_from_login(self):
        registration = self.client.post(
            "/api/driver/register",
            json={"driver": "Pending Driver", "phone": "9876501234", "pin": "123456"},
        )
        self.assertEqual(registration.status_code, 202, registration.get_json())
        self.assertNotIn("token", registration.get_json())
        self.assertEqual(registration.get_json()["driver"]["approval_status"], "pending")
        self.assertIn(
            "do not need to enter a license or vehicle number",
            registration.get_json()["message"].lower(),
        )
        self.assertTrue(registration.get_json()["driver"]["vehicle_number"].startswith("PENDING-"))
        login = self.client.post(
            "/api/driver/login", json={"phone": "9876501234", "pin": "123456"}
        )
        self.assertEqual(login.status_code, 403)
        self.assertIn("administrator completes verification", login.get_json()["message"].lower())
        admin = self.client.post(
            "/api/login",
            json={"username": "admin", "password": "rapidcare-test-only-password"},
        )
        self.assertEqual(admin.status_code, 200, admin.get_json())
        headers = {"Authorization": f"Bearer {admin.get_json()['token']}"}
        queue = self.client.get("/api/admin/driver-requests", headers=headers)
        self.assertEqual(queue.status_code, 200, queue.get_json())
        self.assertEqual(len(queue.get_json()), 1)
        self.assertEqual(queue.get_json()[0]["vehicle_number"], "Assign during approval")
        self.assertEqual(queue.get_json()[0]["license_number"], "Verify during approval")
        missing_details = self.client.patch(
            f"/api/admin/driver-requests/{registration.get_json()['driver']['id']}",
            json={"decision": "approved"},
            headers=headers,
        )
        self.assertEqual(missing_details.status_code, 400, missing_details.get_json())
        approved = self.client.patch(
            f"/api/admin/driver-requests/{registration.get_json()['driver']['id']}",
            json={
                "decision": "approved",
                "vehicle_number": "MH02TEST1234",
                "license_number": "DL-TEST",
            },
            headers=headers,
        )
        self.assertEqual(approved.status_code, 200, approved.get_json())
        self.assertEqual(approved.get_json()["driver"]["vehicle_number"], "MH02TEST1234")
        login = self.client.post(
            "/api/driver/login", json={"phone": "9876501234", "pin": "123456"}
        )
        self.assertEqual(login.status_code, 200, login.get_json())
        self.assertEqual(login.get_json()["driver"]["status"], "Offline")
        driver_id = registration.get_json()["driver"]["id"]
        driver_headers = {"Authorization": f"Bearer {login.get_json()['token']}"}
        shift = self.client.patch(
            f"/api/driver/{driver_id}/status",
            json={"status": "Available"},
            headers=driver_headers,
        )
        self.assertEqual(shift.status_code, 200, shift.get_json())
        fleet_add = self.client.post(
            "/api/admin/fleet",
            json={"driver": "Admin Unit", "vehicle_number": "MH02ADMIN1"},
            headers=headers,
        )
        self.assertEqual(fleet_add.status_code, 201, fleet_add.get_json())

    def test_hospital_staff_capacity_update_is_shared_with_login_free_patient_feed(self):
        login = self.client.post(
            "/api/login",
            json={"username": "doctor", "password": "rapidcare-test-only-password"},
        )
        self.assertEqual(login.status_code, 200, login.get_json())
        staff_headers = {"Authorization": f"Bearer {login.get_json()['token']}"}
        update = self.client.post(
            "/api/hospital/state",
            json={"available_beds": 77, "icu_beds": 11},
            headers=staff_headers,
        )
        self.assertEqual(update.status_code, 200, update.get_json())

        # A second client represents another phone opening the same shared API without patient login.
        patient_client = app.test_client()
        hospitals = patient_client.get(
            "/api/app/hospitals?type=cardiac&lat=19.17&lng=72.85"
        )
        self.assertEqual(hospitals.status_code, 200, hospitals.get_json())
        hospital = next(item for item in hospitals.get_json() if item["id"] == 1)
        self.assertEqual(hospital["available_beds"], 77)
        self.assertEqual(hospital["icu_beds"], 11)

    def test_admin_capacity_editor_updates_any_hospital_for_anonymous_patients(self):
        admin = self.client.post(
            "/api/login",
            json={"username": "admin", "password": "rapidcare-test-only-password"},
        )
        self.assertEqual(admin.status_code, 200, admin.get_json())
        admin_headers = {"Authorization": f"Bearer {admin.get_json()['token']}"}

        unauthorized = self.client.patch(
            "/api/admin/hospitals/2", json={"general_beds": 31}
        )
        self.assertEqual(unauthorized.status_code, 401)
        update = self.client.patch(
            "/api/admin/hospitals/2",
            json={"general_beds": 31, "icu_beds": 8},
            headers=admin_headers,
        )
        self.assertEqual(update.status_code, 200, update.get_json())
        invalid = self.client.patch(
            "/api/admin/hospitals/2",
            json={"general_beds": -1},
            headers=admin_headers,
        )
        self.assertEqual(invalid.status_code, 400, invalid.get_json())

        anonymous_patient = app.test_client()
        hospitals = anonymous_patient.get("/api/app/hospitals?type=cardiac")
        self.assertEqual(hospitals.status_code, 200, hospitals.get_json())
        hospital = next(item for item in hospitals.get_json() if item["id"] == 2)
        self.assertEqual(hospital["available_beds"], 31)
        self.assertEqual(hospital["icu_beds"], 8)


if __name__ == "__main__":
    unittest.main()
