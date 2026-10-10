import math
import os
import secrets
import time
from datetime import datetime, timedelta, timezone

import requests
from flask import Flask, jsonify, render_template, request, session
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.exc import IntegrityError
from itsdangerous import BadData, URLSafeTimedSerializer
from werkzeug.security import check_password_hash, generate_password_hash

app = Flask(__name__)
APP_ENV = os.environ.get("RAPIDCARE_ENV", "development").strip().lower()
IS_PRODUCTION = APP_ENV == "production"
configured_secret = os.environ.get("RAPIDCARE_SECRET", "").strip()
if IS_PRODUCTION and len(configured_secret) < 32:
    raise RuntimeError("Set RAPIDCARE_SECRET to a random value of at least 32 characters in production.")
app.config["SECRET_KEY"] = configured_secret or secrets.token_urlsafe(48)
extra_cors_origins = [origin.strip() for origin in os.environ.get("RAPIDCARE_CORS_ORIGINS", "").split(",") if origin.strip()]
CORS(app, origins=[r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"] + extra_cors_origins)
app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get(
    "RAPIDCARE_DATABASE_URI", "sqlite:///rapidcare.malad-goregaon.demo.db"
)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
app.config["SESSION_COOKIE_HTTPONLY"] = True
app.config["SESSION_COOKIE_SAMESITE"] = "Lax"
app.config["SESSION_COOKIE_SECURE"] = IS_PRODUCTION or os.environ.get("RAPIDCARE_COOKIE_SECURE", "").lower() in {"1", "true", "yes"}
db = SQLAlchemy(app)

signer = URLSafeTimedSerializer(app.config["SECRET_KEY"], salt="rapidcare-auth")
SLACK_WEBHOOK_URL = ""
DEMO_PHONE = os.environ.get("RAPIDCARE_DEMO_PHONE", "")
DEMO_PASSWORD = os.environ.get("RAPIDCARE_DEMO_PASSWORD", "").strip()
if not DEMO_PASSWORD:
    # Keep the displayed development demo account usable after a fresh setup.
    # Production still requires an explicitly configured password at seeding time.
    DEMO_PASSWORD = "rapidcare123" if not IS_PRODUCTION else secrets.token_urlsafe(14)
AUTH_FAILURES = {}
AUTH_WINDOW_SECONDS = 600
AUTH_MAX_FAILURES = 5


def login_rate_limit_key():
    ip = request.remote_addr or "unknown"
    now = time.monotonic()
    recent = [stamp for stamp in AUTH_FAILURES.get(ip, []) if now - stamp < AUTH_WINDOW_SECONDS]
    if recent:
        AUTH_FAILURES[ip] = recent
    else:
        AUTH_FAILURES.pop(ip, None)
    if len(AUTH_FAILURES) > 4096:
        for address, stamps in list(AUTH_FAILURES.items()):
            valid = [stamp for stamp in stamps if now - stamp < AUTH_WINDOW_SECONDS]
            if valid:
                AUTH_FAILURES[address] = valid
            else:
                AUTH_FAILURES.pop(address, None)
    if len(recent) >= AUTH_MAX_FAILURES:
        return None, (jsonify({"success": False, "message": "Too many failed sign-in attempts. Wait 10 minutes and try again."}), 429, {"Retry-After": str(AUTH_WINDOW_SECONDS)})
    return ip, None


def record_login_failure(ip):
    AUTH_FAILURES.setdefault(ip, []).append(time.monotonic())


def clear_login_failures(ip):
    AUTH_FAILURES.pop(ip, None)
def utcnow():
    return datetime.now(timezone.utc)


class HospitalModel(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(200), default="Lifeline Medicare Hospital")
    location = db.Column(db.String(300), default="")
    phone = db.Column(db.String(50), default="")
    status = db.Column(db.String(100), default="Accepting Emergency Dispatches")
    active = db.Column(db.Boolean, default=True)
    lat = db.Column(db.Float)
    lng = db.Column(db.Float)
    rating = db.Column(db.Float, default=4.5)
    available_beds = db.Column(db.Integer, default=18)
    icu_beds = db.Column(db.Integer, default=3)
    ed_status = db.Column(db.String(100), default="OPEN • ACCEPTING PATIENTS")
    cardiac_unit = db.Column(db.Boolean, default=False)
    trauma_unit = db.Column(db.Boolean, default=True)
    burn_unit = db.Column(db.Boolean, default=False)
    maternity_ot = db.Column(db.Boolean, default=True)
    cardiologist = db.Column(db.Boolean, default=True)
    trauma_surgeon = db.Column(db.Boolean, default=True)
    intensivist = db.Column(db.Boolean, default=True)
    neurosurgeon = db.Column(db.Boolean, default=False)
    plastic_surgeon = db.Column(db.Boolean, default=False)
    obgyn = db.Column(db.Boolean, default=True)
    orthopaedic = db.Column(db.Boolean, default=False)
    pediatrician = db.Column(db.Boolean, default=False)
    emergency_physician = db.Column(db.Boolean, default=True)
    cath_lab = db.Column(db.Boolean, default=True)
    level1_trauma = db.Column(db.Boolean, default=True)
    ventilator_icu = db.Column(db.Boolean, default=True)
    burn_ward = db.Column(db.Boolean, default=False)
    nicu = db.Column(db.Boolean, default=False)
    ct_mri = db.Column(db.Boolean, default=True)
    blood_bank = db.Column(db.Boolean, default=True)
    emergency_ot = db.Column(db.Boolean, default=False)


class AmbulanceModel(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    vehicle_number = db.Column(db.String(50), nullable=False)
    driver = db.Column(db.String(150), nullable=False)
    phone = db.Column(db.String(50), default="")
    pin_hash = db.Column(db.String(255))
    license_number = db.Column(db.String(100))
    type = db.Column(db.String(80), default="BLS (Basic Life Support)")
    status = db.Column(db.String(100), default="Available")
    lat = db.Column(db.Float)
    lng = db.Column(db.Float)
    updated_at = db.Column(db.DateTime, default=utcnow)


class EmergencyModel(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    code = db.Column(db.String(30), default="")
    patient_name = db.Column(db.String(150), default="Unknown")
    patient_phone = db.Column(db.String(50), default="")
    emergency_type = db.Column(db.String(50), default="other")
    triage_level = db.Column(db.String(50), default="Critical")
    lat = db.Column(db.Float)
    lng = db.Column(db.Float)
    hospital_id = db.Column(db.Integer)
    ambulance_id = db.Column(db.Integer)
    status = db.Column(db.String(30), default="incoming")
    eta_min = db.Column(db.Integer)
    created_at = db.Column(db.DateTime, default=utcnow)
    updated_at = db.Column(db.DateTime, default=utcnow, onupdate=utcnow)


class PatientAccountModel(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    email = db.Column(db.String(254), unique=True, nullable=False, index=True)
    phone = db.Column(db.String(20), nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=utcnow)


class StaffAccountModel(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(40), nullable=False)
    hospital_id = db.Column(db.Integer)


class ReviewModel(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    facility_type = db.Column(db.String(20), nullable=False, index=True)
    facility_id = db.Column(db.Integer, nullable=False, index=True)
    rating = db.Column(db.Integer, nullable=False)
    comment = db.Column(db.String(1200), default="", nullable=False)
    status = db.Column(db.String(20), default="pending", nullable=False, index=True)
    submitted_at = db.Column(db.DateTime, default=utcnow, nullable=False)
    reported = db.Column(db.Boolean, default=False, nullable=False)
    report_reason = db.Column(db.String(600), default="", nullable=False)
    reported_at = db.Column(db.DateTime)


class SyncStatusModel(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    last_sync_at = db.Column(db.DateTime, nullable=False, default=utcnow)


def facility_model(facility_type, facility_id):
    if facility_type != "hospital":
        return None
    return db.session.get(HospitalModel, facility_id)


def facility_rating(facility_type, facility_id):
    rows = ReviewModel.query.filter_by(
        facility_type=facility_type, facility_id=facility_id, status="approved"
    ).with_entities(ReviewModel.rating).all()
    return (round(sum(row[0] for row in rows) / len(rows), 1), len(rows)) if rows else (None, 0)


def review_dict(review, include_moderation=False):
    facility = facility_model(review.facility_type, review.facility_id)
    result = {
        "id": review.id, "facility_type": review.facility_type,
        "facility_id": review.facility_id,
        "facility_name": facility.name if facility else "Unknown facility",
        "rating": review.rating, "comment": review.comment,
        "status": review.status,
        "submitted_at": review.submitted_at.isoformat() if review.submitted_at else None,
    }
    if include_moderation:
        result.update({
            "reported": review.reported, "report_reason": review.report_reason,
            "reported_at": review.reported_at.isoformat() if review.reported_at else None,
        })
    return result


UNITS = {
    "cardiac_unit": "cardiac_unit", "trauma_unit": "trauma_unit",
    "burn_unit": "burn_unit", "maternity_ot": "maternity_ot"
}
SPECIALISTS = {
    "Cardiologist": "cardiologist", "Trauma Surgeon": "trauma_surgeon",
    "Intensivist": "intensivist", "Neurosurgeon": "neurosurgeon",
    "Plastic & Burn Surgeon": "plastic_surgeon",
    "Obstetrician & Gynecologist": "obgyn", "Orthopaedic": "orthopaedic",
    "Pediatrician": "pediatrician", "Emergency Physician": "emergency_physician"
}
FACILITIES = {
    "24x7 Cath Lab": "cath_lab", "Level-1 Trauma Bay": "level1_trauma",
    "Ventilator ICU": "ventilator_icu", "Burn Isolation Ward": "burn_ward",
    "NICU": "nicu", "CT / MRI": "ct_mri", "Blood Bank": "blood_bank",
    "Emergency OT": "emergency_ot"
}
TYPE_NEEDS = {
    "cardiac": ("cardiologist", "cath_lab"),
    "burn": ("plastic_surgeon", "burn_ward"),
    "trauma": ("orthopaedic", "emergency_physician"),
    "accident": ("orthopaedic", "emergency_physician"),
    "pregnancy": ("obgyn", "maternity_ot"),
    "other": ("emergency_physician", "ct_mri")
}

# Only published facility services are seeded as available for recommendations.
HOSPITAL_CAPABILITY_FIELDS = tuple(dict.fromkeys(
    list(UNITS.values()) + list(SPECIALISTS.values()) + list(FACILITIES.values())
))
VERIFIED_HOSPITAL_CAPABILITIES = {
    "Zeinith Multispeciality Hospital": {"cardiologist", "orthopaedic", "obgyn", "pediatrician", "emergency_physician"},
    "Savitri Bai Phule BMC Hospital": set(),
    "Government General Hospital, Malwani Malad": set(),
    "Ashoka General Hospital I.C.C.U and Maternity Home": {"cardiologist", "orthopaedic", "obgyn", "emergency_physician"},
    "Suvidha Hospital and Iccu": set(),
    "SRV Hospital": {"cardiac_unit", "cardiologist", "orthopaedic", "obgyn", "emergency_physician", "cath_lab"},
    "Life Line Medicare Hospital Pvt Ltd": {"obgyn", "maternity_ot", "pediatrician", "ventilator_icu"},
    "Dr. Sabnis Hospital": set(),
    "Siddharth Municipal General Hospital": set(),
    "Trauma Hospital": set(),
}
ACTIVE_CASE = ("incoming", "accepted", "en_route", "arrived", "picked_up")
LIVE_CASE = ACTIVE_CASE + ("reached_hospital",)
IN_TRANSIT = ("accepted", "en_route", "picked_up")

def seed_all():
    if not HospitalModel.query.first():
        rows = [
            ("Zeinith Multispeciality Hospital", "Parth Business Plaza, New Link Road, Mith Chowky, Orlem, Malad West, Mumbai, Maharashtra 400064", "022-28837863", 14, 4, 19.196729, 72.834163),
            ("Savitri Bai Phule BMC Hospital", "Riddhi Garden Road, Malad East, Mumbai, Maharashtra 400097", "022-28492388", 28, 6, 19.1777529, 72.8724378),
            ("Government General Hospital, Malwani Malad", "Bhoomi Park Road, Janakalyan Nagar, Malwani, Mumbai, Maharashtra 400095", "9869320123", 18, 4, 19.2007076, 72.8221715),
            ("Ashoka General Hospital I.C.C.U and Maternity Home", "First Floor, Ashoka Palace, Makrani Pada, Matanpur Nagar, Malad East, Mumbai, Maharashtra 400097", "022-28775084", 14, 3, 19.1818080, 72.8531321),
            ("Suvidha Hospital and Iccu", "No. 4, Neelam Apartments, near Triveni Nagar, Kokani Pada, Kurar, Malad East, Mumbai, Maharashtra 400097", "022-28431963", 10, 3, 19.198999, 72.866717),
            ("SRV Hospital", "179/180, Road No. 2, Kamal Charan Building, Jawahar Nagar, Goregaon West, Mumbai, Maharashtra 400062", "022-68840000", 16, 5, 19.1589907, 72.8492265),
            ("Life Line Medicare Hospital Pvt Ltd", "A/1, Gagan Chambers, near Gokuldham Medical Centre, Gokuldham, Goregaon East, Mumbai, Maharashtra 400063", "022-68478175", 12, 4, 19.1723310, 72.8684660),
            ("Dr. Sabnis Hospital", "6A, Nivara Building, Naikwadi Road, Churi Wadi, Goregaon East, Mumbai, Maharashtra 400063", "9821140973", 10, 3, 19.1671157, 72.8513635),
            ("Siddharth Municipal General Hospital", "Siddharth Municipal General Hospital, Lokmanya Tilak Road No. 5, New Siddharth Nagar, Goregaon West, Mumbai, Maharashtra 400104", "022-28766885", 20, 5, 19.1595728, 72.8403060),
            ("Trauma Hospital", "I B Patel Road, Goregaon East, Mumbai, Maharashtra 400063", "", 12, 4, 19.1604330, 72.8562440),
        ]
        db.session.add_all([
            HospitalModel(name=n, location=a, phone=ph,
                          status="Listed",
                          ed_status="Call to confirm",
                          available_beds=b, icu_beds=i, lat=la, lng=lo,
                          rating=None,
                          **{field: field in VERIFIED_HOSPITAL_CAPABILITIES.get(n, set())
                             for field in HOSPITAL_CAPABILITY_FIELDS})
            for n, a, ph, b, i, la, lo in rows
        ])

    db.session.flush()

    pw = generate_password_hash(DEMO_PASSWORD)
    demo_accounts = [
        ("admin", "Admin", None),
        ("doctor", "Hospital Staff", 1),
    ]
    if IS_PRODUCTION and not os.environ.get("RAPIDCARE_DEMO_PASSWORD", "").strip() and any(
        not StaffAccountModel.query.filter_by(username=username).first()
        for username, _, _ in demo_accounts
    ):
        raise RuntimeError("Set RAPIDCARE_DEMO_PASSWORD before production startup when demo staff accounts need to be created.")
    created_demo_accounts = []
    for username, role, hospital_id in demo_accounts:
        if not StaffAccountModel.query.filter_by(username=username).first():
            db.session.add(StaffAccountModel(
                username=username, password_hash=pw, role=role,
                hospital_id=hospital_id
            ))
            created_demo_accounts.append(username)

    if not AmbulanceModel.query.first():
        rows = [
            ("Rajesh Patil", "MH-02-ER-1081", "Cardiac ICU Van", "Available", 19.1670, 72.8540),
            ("Amit Shinde", "MH-02-AM-4022", "ALS (Advanced Life Support)", "Available", 19.1800, 72.8450),
            ("Suresh Verma", "MH-02-BLS-8890", "BLS (Basic Life Support)", "Available", 19.1700, 72.8600),
            ("Vikram More", "MH-02-ER-5531", "ALS (Advanced Life Support)", "Offline", None, None),
            ("Ganesh Pawar", "MH-02-BLS-3120", "BLS (Basic Life Support)", "Available", 19.1400, 72.8300),
        ]
        db.session.add_all([
            AmbulanceModel(driver=d, phone=DEMO_PHONE, vehicle_number=v,
                           type=t, status=st, lat=la, lng=lo,
                           updated_at=datetime(2000, 1, 1))
            for d, v, t, st, la, lo in rows
        ])

    db.session.commit()
    if created_demo_accounts and not os.environ.get("RAPIDCARE_DEMO_PASSWORD"):
        app.logger.warning(
            "Generated a one-time demo password for %s: %s. Save it now; set RAPIDCARE_DEMO_PASSWORD to choose a stable value.",
            ", ".join(created_demo_accounts), DEMO_PASSWORD
        )


with app.app_context():
    db.create_all()
    seed_all()


def send_slack_alert(message):
    if "hooks.slack.com" not in SLACK_WEBHOOK_URL:
        return
    try:
        requests.post(
            SLACK_WEBHOOK_URL,
            json={"text": f"🚨 *RapidCare Central Alert*\n{message}"},
            timeout=5
        )
    except Exception as e:
        print(f"Failed to send Slack alert: {e}")


def km(lat1, lng1, lat2, lng2):
    p1, p2 = math.radians(lat1), math.radians(lat2)
    a = (
        math.sin((p2 - p1) / 2) ** 2
        + math.cos(p1) * math.cos(p2)
        * math.sin(math.radians(lng2 - lng1) / 2) ** 2
    )
    return 6371 * 2 * math.asin(math.sqrt(a))


def eta_minutes(dist_km):
    return max(2, round(dist_km / 30 * 60))


def naive_now():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def gps_age(a):
    if a.lat is None or a.lng is None or not a.updated_at:
        return None
    return (naive_now() - a.updated_at.replace(tzinfo=None)).total_seconds()


def fresh(a, seconds=300):
    age = gps_age(a)
    return age is not None and age <= seconds


def expire_stale():
    cutoff = naive_now() - timedelta(hours=3)
    changed = False
    for c in EmergencyModel.query.filter(
        EmergencyModel.status.in_(LIVE_CASE),
        EmergencyModel.updated_at < cutoff
    ):
        c.status = "completed" if c.status == "reached_hospital" else "cancelled"
        changed = True
    if changed:
        db.session.commit()


def busy_ids():
    expire_stale()
    return {
        c.ambulance_id for c in EmergencyModel.query.filter(
            EmergencyModel.ambulance_id.isnot(None),
            EmergencyModel.status.in_(LIVE_CASE)
        )
    }


def refresh_status(a, busy=None):
    if a.status == "Offline":
        return
    busy = busy_ids() if busy is None else busy
    a.status = "En Route" if a.id in busy else "Available"


def assign_ambulance(e):
    if e.ambulance_id or e.lat is None or e.lng is None:
        return bool(e.ambulance_id)
    busy = busy_ids()
    free = [
        a for a in AmbulanceModel.query
        if a.status != "Offline" and fresh(a) and a.id not in busy
    ]
    if not free:
        return False
    e.ambulance_id = min(
        free, key=lambda a: km(e.lat, e.lng, a.lat, a.lng)
    ).id
    return True


def hospital_admin_dict(h):
    avg, count = facility_rating("hospital", h.id)
    return {
        "id": h.id, "name": h.name, "location": h.location, "phone": h.phone,
        "general_beds": h.available_beds, "icu_beds": h.icu_beds,
        "status": h.status, "active": h.active, "lat": h.lat, "lng": h.lng,
        "rating": avg if count else h.rating, "review_count": count
    }


def hospital_state_dict(h):
    avg, count = facility_rating("hospital", h.id)
    return {
        "id": h.id, "name": h.name, "location": h.location, "phone": h.phone,
        "status": h.status, "active": h.active, "lat": h.lat, "lng": h.lng,
        "rating": avg if count else h.rating, "review_count": count,
        "available_beds": h.available_beds,
        "icu_beds": h.icu_beds, "ed_status": h.ed_status,
        "units": {k: getattr(h, c) for k, c in UNITS.items()},
        "specialists": {k: getattr(h, c) for k, c in SPECIALISTS.items()},
        "facilities": {k: getattr(h, c) for k, c in FACILITIES.items()}
    }


def ambulance_dict(a):
    has_live_gps = fresh(a)
    return {
        "id": a.id, "vehicle_number": a.vehicle_number, "driver": a.driver,
        "phone": a.phone, "type": a.type, "status": a.status,
        "lat": a.lat, "lng": a.lng,
        "updated_at": a.updated_at.isoformat() if a.updated_at else None,
        "location_is_live": has_live_gps,
        "status_label": (
            "Live driver GPS received"
            if has_live_gps else "Location unavailable"
        )
    }


def emergency_dict(e):
    h = db.session.get(HospitalModel, e.hospital_id) if e.hospital_id else None
    a = db.session.get(AmbulanceModel, e.ambulance_id) if e.ambulance_id else None
    return {
        "id": e.id, "code": e.code, "patient_name": e.patient_name,
        "patient_phone": e.patient_phone, "emergency_type": e.emergency_type,
        "triage_level": e.triage_level, "status": e.status,
        "lat": e.lat, "lng": e.lng, "hospital_id": e.hospital_id,
        "hospital": h.name if h else None,
        "hospital_info": (
            {"id": h.id, "name": h.name, "location": h.location,
             "phone": h.phone, "lat": h.lat, "lng": h.lng}
            if h else None
        ),
        "ambulance_id": e.ambulance_id,
        "ambulance": a.vehicle_number if a else None,
        "ambulance_info": (
            {"id": a.id, "driver": a.driver, "phone": a.phone,
             "vehicle_number": a.vehicle_number, "type": a.type,
             "status": a.status, "lat": a.lat, "lng": a.lng}
            if a else None
        ),
        "eta": f"{e.eta_min} mins" if e.eta_min else None,
        "created_at": e.created_at.isoformat() if e.created_at else None
    }


def pick_hospital():
    hid = request.args.get("hospital_id", type=int)
    if not hid:
        hid = (request.get_json(silent=True) or {}).get("hospital_id")
    if hid:
        return db.session.get(HospitalModel, int(hid))
    return HospitalModel.query.order_by(HospitalModel.id).first()


def create_emergency(data):
    lat, lng = data.get("lat"), data.get("lng")
    e = EmergencyModel(
        patient_name=data.get("patient_name") or "Unknown",
        patient_phone=data.get("patient_phone") or "",
        emergency_type=(data.get("emergency_type") or "other").lower(),
        triage_level=data.get("triage_level") or "Critical",
        lat=lat, lng=lng, hospital_id=data.get("hospital_id")
    )
    h = db.session.get(HospitalModel, e.hospital_id) if e.hospital_id else None
    if h and None not in (lat, lng, h.lat, h.lng):
        e.eta_min = eta_minutes(km(lat, lng, h.lat, h.lng))
    assign_ambulance(e)
    db.session.add(e)
    db.session.flush()
    e.code = f"EMG-{e.id:04d}"
    db.session.commit()
    send_slack_alert(
        f"New Emergency Patient Dispatched to *{h.name if h else 'network'}*!\n"
        f"• *Patient:* {e.patient_name}\n"
        f"• *Triage:* {e.triage_level}\n"
        f"• *ETA:* {e.eta_min or '?'} mins"
    )
    return e


# Portal routes
@app.route("/")
def admin_portal():
    return render_template("admin/index.html")


@app.route("/hospital")
def hospital_portal():
    return render_template("hospital staff/hospital.html")


@app.route("/login")
@app.route("/staff")
@app.route("/staff/login")
def staff_portal():
    return render_template(
        "staff/login.html",
        demo_password=DEMO_PASSWORD if not IS_PRODUCTION else None,
    )


# Authentication
def staff_info(acct):
    return {
        "id": acct.id, "username": acct.username, "role": acct.role,
        "hospital_id": acct.hospital_id
    }


def current_staff():
    # A Bearer token, when present, is the ONLY credential considered.
    # It takes precedence over the shared Flask session cookie, so a login
    # in another portal tab can never change who this request is
    # authenticated as. An invalid/expired token means "not signed in"
    # (it never falls back to the cookie).
    auth = request.headers.get("Authorization", "")
    if auth.startswith("Bearer "):
        try:
            payload = signer.loads(auth[7:], max_age=12 * 3600)
        except BadData:
            return None
        if not isinstance(payload, dict) or payload.get("kind") != "staff":
            return None
        acct = db.session.get(StaffAccountModel, payload.get("id"))
        return staff_info(acct) if acct else None

    # Session-cookie authentication (kept for existing cookie-only pages).
    sid = session.get("staff_id")
    if sid is not None:
        acct = db.session.get(StaffAccountModel, sid)
        if not acct:
            session.clear()
            return None
        return staff_info(acct)
    return None


def bearer_payload():
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None
    try:
        payload = signer.loads(auth[7:], max_age=12 * 3600)
        return payload if isinstance(payload, dict) else None
    except BadData:
        return None


def current_driver():
    payload = bearer_payload()
    if not payload or payload.get("kind") != "driver":
        return None
    return db.session.get(AmbulanceModel, payload.get("id"))


def require_driver(ambulance_id=None):
    driver = current_driver()
    if not driver:
        return None, (jsonify({"success": False, "message": "Driver sign-in required."}), 401)
    if ambulance_id is not None and driver.id != ambulance_id:
        return None, (jsonify({"success": False, "message": "This driver session cannot access another ambulance."}), 403)
    return driver, None


def emergency_access_role(emergency):
    payload = bearer_payload()
    if not payload:
        return None
    if payload.get("kind") == "patient_emergency" and payload.get("id") == emergency.id:
        return "patient"
    if payload.get("kind") == "driver" and payload.get("id") == emergency.ambulance_id:
        return "driver"
    return None


def require_role(*roles):
    staff = current_staff()
    if not staff:
        return None, (jsonify({"success": False, "message": "Please sign in first"}), 401)
    if roles and staff["role"] not in roles:
        return None, (jsonify({"success": False, "message": "Access denied"}), 403)
    return staff, None


def admin_required():
    return require_role("Admin")


def login_staff(issue_token=False):
    ip, blocked = login_rate_limit_key()
    if blocked:
        return blocked
    data = request.get_json(silent=True) or {}
    if not isinstance(data, dict):
        return jsonify({"success": False, "message": "Invalid username or password"}), 400
    username = (data.get("username") or "").strip().lower()
    password = data.get("password") or ""
    if not isinstance(password, str):
        password = ""
    acct = StaffAccountModel.query.filter(
        db.func.lower(StaffAccountModel.username) == username
    ).first()

    if not acct or not check_password_hash(acct.password_hash, password):
        record_login_failure(ip)
        return jsonify({"success": False, "message": "Invalid username or password"}), 401
    clear_login_failures(ip)

    # Token-mode logins (/api/login) do NOT touch the shared session cookie,
    # so they cannot replace another portal tab's session.
    # Cookie-mode logins (/api/auth/login) set the session as before.
    if not issue_token:
        session.clear()
        session["staff_id"] = acct.id
        session["role"] = acct.role
        if acct.hospital_id is not None:
            session["hospital_id"] = acct.hospital_id

    response = {
        "success": True,
        "message": "Login successful",
        "role": acct.role,
        "hospital_id": acct.hospital_id,
        "user": staff_info(acct),
        "token": signer.dumps({
            "kind": "staff", "id": acct.id, "role": acct.role, "hospital_id": acct.hospital_id
        })
    }
    result = jsonify(response)
    result.headers["Cache-Control"] = "no-store"
    return result


@app.route("/api/auth/login", methods=["POST"])
def auth_login():
    return login_staff(False)


@app.route("/api/login", methods=["POST"])
def staff_login():
    return login_staff(True)


def patient_info(account):
    return {
        "id": account.id,
        "name": account.name,
        "email": account.email,
        "phone": account.phone,
    }


def patient_from_token():
    authorization = request.headers.get("Authorization", "")
    if not authorization.startswith("Bearer "):
        return None
    try:
        payload = signer.loads(authorization[7:], max_age=12 * 3600)
    except BadData:
        return None
    if not isinstance(payload, dict) or payload.get("kind") != "patient":
        return None
    return db.session.get(PatientAccountModel, payload.get("id"))


def require_patient():
    account = patient_from_token()
    if not account:
        return None, (jsonify({"success": False, "message": "Patient sign-in required."}), 401)
    return account, None


@app.route("/api/patient/register", methods=["POST"])
def patient_register():
    ip, blocked = login_rate_limit_key()
    if blocked:
        return blocked
    data = request.get_json(silent=True) or {}
    if not isinstance(data, dict):
        return jsonify({"success": False, "message": "Enter your account details."}), 400
    name = " ".join(str(data.get("name") or "").split())[:120]
    email = str(data.get("email") or "").strip().lower()
    raw_phone = str(data.get("phone") or "")
    phone = "".join(character for character in raw_phone if character.isdigit())
    if len(phone) == 12 and phone.startswith("91"):
        phone = phone[2:]
    password = data.get("password") or ""
    if not isinstance(password, str):
        password = ""
    valid_email = len(email) <= 254 and email.count("@") == 1 and "." in email.rsplit("@", 1)[-1]
    if not name or not valid_email or len(phone) != 10 or not password:
        record_login_failure(ip)
        return jsonify({"success": False, "message": "Enter your name, a valid email, and a 10-digit phone number."}), 400
    if len(password) < 8:
        record_login_failure(ip)
        return jsonify({"success": False, "message": "Use a password with at least 8 characters."}), 400
    if PatientAccountModel.query.filter(db.func.lower(PatientAccountModel.email) == email).first():
        record_login_failure(ip)
        return jsonify({"success": False, "message": "An account with this email already exists. Sign in instead."}), 409
    account = PatientAccountModel(
        name=name, email=email, phone=phone,
        password_hash=generate_password_hash(password),
    )
    db.session.add(account)
    try:
        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        record_login_failure(ip)
        return jsonify({"success": False, "message": "An account with this email already exists. Sign in instead."}), 409
    clear_login_failures(ip)
    token = signer.dumps({"kind": "patient", "id": account.id})
    response = jsonify({"success": True, "token": token, "user": patient_info(account)})
    response.status_code = 201
    response.headers["Cache-Control"] = "no-store"
    return response


@app.route("/api/patient/login", methods=["POST"])
def patient_login():
    ip, blocked = login_rate_limit_key()
    if blocked:
        return blocked
    data = request.get_json(silent=True) or {}
    email = str(data.get("email") or "").strip().lower() if isinstance(data, dict) else ""
    password = data.get("password") or "" if isinstance(data, dict) else ""
    if not isinstance(password, str):
        password = ""
    account = PatientAccountModel.query.filter(
        db.func.lower(PatientAccountModel.email) == email
    ).first() if email else None
    if not account or not check_password_hash(account.password_hash, password):
        record_login_failure(ip)
        return jsonify({"success": False, "message": "Email or password is incorrect."}), 401
    clear_login_failures(ip)
    token = signer.dumps({"kind": "patient", "id": account.id})
    response = jsonify({"success": True, "token": token, "user": patient_info(account)})
    response.headers["Cache-Control"] = "no-store"
    return response


@app.route("/api/patient/me", methods=["GET"])
def patient_me():
    account, error = require_patient()
    if error:
        return error
    return jsonify({"success": True, "user": patient_info(account)})


@app.route("/api/auth/logout", methods=["POST"])
def auth_logout():
    # Bearer-token clients just discard their token; clearing the shared
    # session cookie here would log out other portals' cookie sessions.
    if not request.headers.get("Authorization", "").startswith("Bearer "):
        session.clear()
    return jsonify({"success": True})


@app.route("/api/admin/me", methods=["GET"])
def admin_me():
    staff, error = admin_required()
    if error:
        return error
    return jsonify({"success": True, "user": staff})


@app.route("/api/hospital/me", methods=["GET"])
def hospital_me():
    staff, error = require_role("Hospital Staff")
    if error:
        return error
    h = db.session.get(HospitalModel, staff["hospital_id"])
    if not h:
        return jsonify({"success": False, "message": "Hospital not found"}), 404
    return jsonify({"success": True, "user": staff, "hospital": hospital_state_dict(h)})


# Hospital
def update_hospital(h, data):
    try:
        if "available_beds" in data:
            h.available_beds = max(0, int(data["available_beds"]))
        if "icu_beds" in data:
            h.icu_beds = max(0, int(data["icu_beds"]))
    except (TypeError, ValueError):
        return False
    for key in ("status", "ed_status"):
        if key in data:
            setattr(h, key, data[key])
    for section, mapping in (
        ("units", UNITS), ("specialists", SPECIALISTS), ("facilities", FACILITIES)
    ):
        for key, col in mapping.items():
            if key in (data.get(section) or {}):
                setattr(h, col, bool(data[section][key]))
    return True


@app.route("/api/hospital/state", methods=["GET"])
def get_hospital_state():
    staff, error = require_role("Hospital Staff")
    if error:
        return error
    h = db.session.get(HospitalModel, staff["hospital_id"])
    return jsonify(hospital_state_dict(h) if h else {})


@app.route("/api/hospital/state", methods=["POST"])
@app.route("/api/hospital/update", methods=["POST"])
def update_hospital_state():
    staff, error = require_role("Hospital Staff")
    if error:
        return error
    h = db.session.get(HospitalModel, staff["hospital_id"])
    if not h:
        return jsonify({"success": False, "message": "Hospital not found"}), 404
    data = request.get_json(silent=True) or {}
    if "lat" in data or "lng" in data:
        return jsonify({
            "success": False,
            "message": "Only an administrator can change the hospital's saved location."
        }), 403
    if not update_hospital(h, data):
        return jsonify({"success": False, "message": "Invalid hospital data"}), 400
    db.session.commit()
    return jsonify({
        "success": True,
        "message": "Hospital state updated successfully",
        "hospital": hospital_state_dict(h)
    })


@app.route("/api/hospital/emergencies", methods=["GET"])
def hospital_emergencies():
    staff, error = require_role("Hospital Staff")
    if error:
        return error
    # LIVE_CASE (not ACTIVE_CASE) so reached_hospital cases stay visible
    # until the hospital completes them.
    q = EmergencyModel.query.filter(
        EmergencyModel.status.in_(LIVE_CASE),
        EmergencyModel.hospital_id == staff["hospital_id"]
    )
    return jsonify([
        emergency_dict(e)
        for e in q.order_by(EmergencyModel.id.desc()).all()
    ])


@app.route("/api/hospital/emergencies/<int:eid>", methods=["PATCH"])
def hospital_update_emergency(eid):
    staff, error = require_role("Hospital Staff")
    if error:
        return error
    e = db.session.get(EmergencyModel, eid)
    if not e:
        return jsonify({"success": False, "message": "Emergency not found"}), 404
    if e.hospital_id != staff["hospital_id"]:
        return jsonify({"success": False, "message": "Access denied"}), 403
    data = request.get_json(silent=True) or {}
    if "status" in data:
        e.status = data["status"]
    if "eta_min" in data:
        try:
            e.eta_min = max(0, int(data["eta_min"]))
        except (TypeError, ValueError):
            return jsonify({"success": False, "message": "Invalid ETA"}), 400
    # Persist the new status before recomputing the ambulance's busy state,
    # so a completed/cancelled case releases its ambulance right away.
    db.session.flush()
    a = db.session.get(AmbulanceModel, e.ambulance_id) if e.ambulance_id else None
    if a:
        refresh_status(a)
    db.session.commit()
    return jsonify({"success": True, "emergency": emergency_dict(e)})


@app.route("/api/hospital/reviews", methods=["GET"])
def hospital_reviews():
    staff, error = require_role("Hospital Staff")
    if error:
        return error
    rows = ReviewModel.query.filter_by(
        facility_type="hospital", facility_id=staff["hospital_id"], status="approved"
    ).order_by(ReviewModel.submitted_at.desc()).all()
    return jsonify([review_dict(r) for r in rows])


def report_review(review_id, hospital_id):
    staff, error = require_role("Hospital Staff")
    if error:
        return error
    if staff["hospital_id"] != hospital_id:
        return jsonify({"success": False, "message": "Access denied"}), 403
    row = db.session.get(ReviewModel, review_id)
    if (
        not row or row.facility_type != "hospital"
        or row.facility_id != hospital_id
    ):
        return jsonify({"success": False, "message": "Review not found"}), 404
    reason = ((request.get_json(silent=True) or {}).get("reason") or "").strip()
    if not reason:
        return jsonify({"success": False, "message": "Please add a reason for the report"}), 400
    if len(reason) > 600:
        return jsonify({"success": False, "message": "Report reason must be 600 characters or fewer"}), 400
    row.reported = True
    row.report_reason = reason
    row.reported_at = naive_now()
    db.session.commit()
    return jsonify({"success": True, "message": "Report sent to Admin for review"})


@app.route("/api/hospital/reviews/<int:review_id>/report", methods=["POST"])
def hospital_report_review(review_id):
    staff, error = require_role("Hospital Staff")
    if error:
        return error
    return report_review(review_id, staff["hospital_id"])


# Patient / Driver
@app.route("/api/app/hospitals", methods=["GET"])
def app_hospitals():
    lat, lng = request.args.get("lat", type=float), request.args.get("lng", type=float)
    if (lat is None) != (lng is None):
        return jsonify({
            "success": False,
            "message": "Provide both latitude and longitude, or neither."
        }), 400
    if lat is not None and not (-90 <= lat <= 90 and -180 <= lng <= 180):
        return jsonify({
            "success": False,
            "message": "Latitude or longitude is outside its valid range."
        }), 400
    spec_col, fac_col = TYPE_NEEDS.get(
        request.args.get("type", "other").lower(), TYPE_NEEDS["other"]
    )
    out = []
    for h in HospitalModel.query.filter_by(active=True):
        ed_state = (h.ed_status or "").upper()
        facility_state = (h.status or "").upper()
        unavailable_markers = ("CLOSED", "NOT ACCEPTING", "UNAVAILABLE")
        if any(marker in ed_state or marker in facility_state for marker in unavailable_markers):
            continue
        d = km(lat, lng, h.lat, h.lng) if None not in (lat, lng, h.lat, h.lng) else None
        specialist_match = bool(getattr(h, spec_col))
        facility_match = bool(getattr(h, fac_col))
        matched_requirements = int(specialist_match) + int(facility_match)
        # Clinical capability fit takes precedence over proximity; distance
        # orders facilities within the same capability tier.
        capability_points = matched_requirements * 100
        proximity_points = 0 if d is None else 40 * max(0.0, 1 - min(d, 20) / 20)
        score = round(capability_points + proximity_points)
        reasons = []
        if matched_requirements == 2:
            reasons.append("Directory lists the required specialist and service")
        elif matched_requirements == 1:
            matched = "specialist" if specialist_match else "service"
            reasons.append(f"Directory lists the required {matched}; the other service requirement is not recorded")
        else:
            reasons.append("The directory does not list the required specialist and service for this emergency type")
        if d is not None:
            reasons.append(f"{d:.1f} km straight-line distance from the selected location")
        else:
            reasons.append("Distance is unavailable until both your location and hospital coordinates are available")
        reasons.append("Call the hospital to confirm current services, capacity, and acceptance")
        out.append({
            **hospital_state_dict(h),
            "distance_km": round(d, 1) if d is not None else None,
            "_distance_sort": d,
            "eta_min": eta_minutes(d) if d is not None else None,
            "distance_method": "straight_line",
            "eta_is_estimate": True,
            "score": score,
            "capability_matches": matched_requirements,
            "capability_requirements": 2,
            "ranking_basis": (
                "capability_and_distance" if matched_requirements and d is not None
                else "capability_only" if matched_requirements
                else "distance_only" if d is not None
                else "directory_order"
            ),
            "recommendation_reasons": reasons,
            "capacity_used_for_ranking": False,
        })
    out.sort(key=lambda x: (
        -x["capability_matches"],
        -x["score"],
        float("inf") if x["_distance_sort"] is None else x["_distance_sort"],
        x["name"].casefold(),
    ))
    for hospital in out:
        hospital.pop("_distance_sort", None)
    return jsonify(out)


@app.route("/api/app/reviews", methods=["GET", "POST"])
def app_reviews():
    if request.method == "GET":
        facility_type = (request.args.get("facility_type") or "").lower()
        facility_id = request.args.get("facility_id", type=int)
        if facility_type != "hospital" or not facility_id:
            return jsonify({"success": False, "message": "A valid facility type and ID are required"}), 400
        facility = facility_model(facility_type, facility_id)
        if not facility:
            return jsonify({"success": False, "message": "Facility not found"}), 404
        rows = ReviewModel.query.filter_by(
            facility_type=facility_type, facility_id=facility_id, status="approved"
        ).order_by(ReviewModel.submitted_at.desc()).all()
        average, count = facility_rating(facility_type, facility_id)
        return jsonify({"reviews": [review_dict(r) for r in rows], "rating": average, "review_count": count})

    data = request.get_json(silent=True) or {}
    facility_type = (data.get("facility_type") or "").lower()
    try:
        facility_id = int(data.get("facility_id"))
        rating = int(data.get("rating"))
    except (TypeError, ValueError):
        return jsonify({"success": False, "message": "A facility and 1–5 star rating are required"}), 400
    if facility_type != "hospital" or not facility_model(facility_type, facility_id):
        return jsonify({"success": False, "message": "Facility not found"}), 404
    if rating < 1 or rating > 5:
        return jsonify({"success": False, "message": "Rating must be from 1 to 5 stars"}), 400
    comment = (data.get("comment") or "").strip()
    if len(comment) > 1200:
        return jsonify({"success": False, "message": "Comment must be 1,200 characters or fewer"}), 400
    row = ReviewModel(
        facility_type=facility_type, facility_id=facility_id,
        rating=rating, comment=comment, status="pending"
    )
    db.session.add(row)
    db.session.commit()
    return jsonify({"success": True, "message": "Review submitted for Admin moderation", "review_id": row.id}), 201


@app.route("/api/app/emergency", methods=["POST"])
def app_create_emergency():
    data = request.get_json(silent=True) or {}
    if not isinstance(data, dict):
        return jsonify({"success": False, "message": "A confirmed pickup latitude and longitude are required."}), 400
    try:
        lat, lng = float(data.get("lat")), float(data.get("lng"))
    except (TypeError, ValueError):
        return jsonify({"success": False, "message": "A confirmed pickup latitude and longitude are required."}), 400
    if not (math.isfinite(lat) and math.isfinite(lng) and -90 <= lat <= 90 and -180 <= lng <= 180):
        return jsonify({"success": False, "message": "Pickup coordinates are outside their valid range."}), 400
    data["lat"], data["lng"] = lat, lng
    emergency = create_emergency(data)
    access_token = signer.dumps({"kind": "patient_emergency", "id": emergency.id})
    response = jsonify({
        "success": True,
        "emergency": emergency_dict(emergency),
        "access_token": access_token,
    })
    response.headers["Cache-Control"] = "no-store"
    return response, 201


@app.route("/api/app/emergency/<int:eid>", methods=["GET"])
def app_get_emergency(eid):
    e = db.session.get(EmergencyModel, eid)
    if not e:
        return jsonify({"message": "Not found"}), 404
    if not emergency_access_role(e):
        return jsonify({"success": False, "message": "A valid emergency or assigned-driver session is required."}), 401
    if e.status == "incoming":
        amb = db.session.get(AmbulanceModel, e.ambulance_id) if e.ambulance_id else None
        if amb and (amb.status == "Offline" or not fresh(amb, 90)):
            e.ambulance_id = None
        if not e.ambulance_id:
            assign_ambulance(e)
        db.session.commit()
    response = jsonify(emergency_dict(e))
    response.headers["Cache-Control"] = "no-store"
    return response


@app.route("/api/app/emergency/<int:eid>/location", methods=["POST"])
def app_update_emergency_location(eid):
    data = request.get_json(silent=True) or {}
    if not isinstance(data, dict):
        return jsonify({"success": False, "message": "Latitude and longitude are required."}), 400
    try:
        lat, lng = float(data.get("lat")), float(data.get("lng"))
    except (TypeError, ValueError):
        return jsonify({"success": False, "message": "Latitude and longitude are required."}), 400
    if not (math.isfinite(lat) and math.isfinite(lng) and -90 <= lat <= 90 and -180 <= lng <= 180):
        return jsonify({"success": False, "message": "Coordinates are outside their valid range."}), 400
    emergency = db.session.get(EmergencyModel, eid)
    if not emergency:
        return jsonify({"success": False, "message": "Emergency not found."}), 404
    if emergency_access_role(emergency) != "patient":
        return jsonify({"success": False, "message": "Only the emergency's patient session can update pickup GPS."}), 403
    if emergency.status in {"completed", "cancelled"}:
        return jsonify({"success": False, "message": "This emergency is no longer active."}), 409
    emergency.lat, emergency.lng = lat, lng
    db.session.commit()
    return jsonify({"success": True, "emergency": emergency_dict(emergency)})


@app.route("/api/app/emergency/<int:eid>", methods=["PATCH"])
def app_update_emergency(eid):
    e = db.session.get(EmergencyModel, eid)
    data = request.get_json(silent=True) or {}
    status = data.get("status") if isinstance(data, dict) else None
    if not e:
        return jsonify({"success": False, "message": "Emergency not found."}), 404
    role = emergency_access_role(e)
    if not role:
        return jsonify({"success": False, "message": "A valid emergency or assigned-driver session is required."}), 401
    patient_statuses = {"cancelled"}
    driver_statuses = {"accepted", "en_route", "arrived", "picked_up", "reached_hospital", "completed"}
    if status not in (patient_statuses if role == "patient" else driver_statuses):
        return jsonify({"success": False, "message": "This session cannot apply that emergency status."}), 403
    e.status = status
    db.session.flush()
    a = db.session.get(AmbulanceModel, e.ambulance_id) if e.ambulance_id else None
    if a:
        refresh_status(a)
    db.session.commit()
    return jsonify({"success": True, "emergency": emergency_dict(e)})


@app.route("/api/driver/location", methods=["POST"])
def driver_location():
    d = request.get_json(silent=True) or {}
    if not isinstance(d, dict):
        return jsonify({"success": False, "message": "ambulance_id, lat and lng required"}), 400
    driver, error = require_driver()
    if error:
        return error
    try:
        submitted_id = int(d.get("ambulance_id"))
    except (TypeError, ValueError):
        submitted_id = None
    if submitted_id != driver.id:
        return jsonify({"success": False, "message": "This driver session cannot update another ambulance."}), 403
    a = driver
    try:
        lat, lng = float(d.get("lat")), float(d.get("lng"))
    except (TypeError, ValueError):
        lat = lng = None
    if not a or lat is None or lng is None:
        return jsonify({
            "success": False,
            "message": "ambulance_id, lat and lng required"
        }), 400
    if not (math.isfinite(lat) and math.isfinite(lng) and -90 <= lat <= 90 and -180 <= lng <= 180):
        return jsonify({"success": False, "message": "Coordinates are outside their valid range."}), 400
    a.lat, a.lng, a.updated_at = lat, lng, utcnow()
    refresh_status(a)
    db.session.commit()
    return jsonify({
        "success": True, "status": a.status, "online": a.status != "Offline"
    })


@app.route("/api/driver/register", methods=["POST"])
def driver_register():
    d = request.get_json(silent=True) or {}
    name = (d.get("driver") or "").strip()
    phone = "".join(ch for ch in str(d.get("phone") or "") if ch.isdigit())[-10:]
    vehicle = (d.get("vehicle_number") or "").strip().upper()
    license_no = (d.get("license_number") or "").strip()
    pin = str(d.get("pin") or "")
    if not all((name, phone, vehicle, license_no)) or len(phone) != 10 or not pin.isdigit() or not 6 <= len(pin) <= 12:
        return jsonify({"success": False, "message": "Enter a name, 10-digit phone, vehicle, license number, and a numeric PIN of 6–12 digits."}), 400
    if AmbulanceModel.query.filter_by(phone=phone).first():
        return jsonify({"success": False, "message": "This phone number is already registered."}), 409
    if AmbulanceModel.query.filter(db.func.lower(AmbulanceModel.vehicle_number) == vehicle.lower()).first():
        return jsonify({"success": False, "message": "This vehicle is already registered."}), 409
    a = AmbulanceModel(
        driver=name, phone=phone, vehicle_number=vehicle,
        type=(d.get("type") or "BLS (Basic Life Support)"),
        status="Available", pin_hash=generate_password_hash(pin),
        license_number=license_no
    )
    db.session.add(a)
    db.session.commit()
    token = signer.dumps({"kind": "driver", "id": a.id})
    response = jsonify({"success": True, "driver": ambulance_dict(a), "token": token})
    response.headers["Cache-Control"] = "no-store"
    return response, 201


@app.route("/api/driver/login", methods=["POST"])
def driver_login():
    ip, blocked = login_rate_limit_key()
    if blocked:
        return blocked
    d = request.get_json(silent=True) or {}
    if not isinstance(d, dict):
        return jsonify({"success": False, "message": "Phone number or PIN is incorrect, or the driver has not registered."}), 400
    phone = "".join(ch for ch in str(d.get("phone") or "") if ch.isdigit())[-10:]
    pin = str(d.get("pin") or "")
    a = AmbulanceModel.query.filter_by(phone=phone).first() if len(phone) == 10 else None
    if not a or not a.pin_hash or not check_password_hash(a.pin_hash, pin):
        record_login_failure(ip)
        return jsonify({"success": False, "message": "Phone number or PIN is incorrect, or the driver has not registered."}), 401
    clear_login_failures(ip)
    a.status = "Available"
    db.session.commit()
    token = signer.dumps({"kind": "driver", "id": a.id})
    response = jsonify({"success": True, "driver": ambulance_dict(a), "token": token})
    response.headers["Cache-Control"] = "no-store"
    return response, 200


@app.route("/api/driver/<int:ambulance_id>/status", methods=["PATCH"])
def driver_status(ambulance_id):
    a, error = require_driver(ambulance_id)
    if error:
        return error
    status = (request.get_json(silent=True) or {}).get("status")
    if not a or status not in ("Available", "Offline"):
        return jsonify({"success": False, "message": "Driver or valid status missing."}), 400
    a.status = status
    if status == "Available":
        a.updated_at = utcnow()
    db.session.commit()
    return jsonify({"success": True, "driver": ambulance_dict(a)})


@app.route("/api/driver/<int:ambulance_id>/case", methods=["GET"])
def driver_case(ambulance_id):
    _, error = require_driver(ambulance_id)
    if error:
        return error
    expire_stale()
    e = (
        EmergencyModel.query
        .filter(
            EmergencyModel.ambulance_id == ambulance_id,
            EmergencyModel.status.in_(LIVE_CASE)
        )
        .order_by(EmergencyModel.id.desc())
        .first()
    )
    return jsonify(emergency_dict(e) if e else {})


@app.route("/api/emergency/dispatch", methods=["POST"])
def receive_emergency_dispatch():
    data = request.get_json(silent=True) or {}
    staff = current_staff()
    if staff and staff["role"] == "Hospital Staff":
        data = dict(data)
        data["hospital_id"] = staff["hospital_id"]
    elif data.get("hospital_id") is not None:
        if not db.session.get(HospitalModel, int(data["hospital_id"])):
            return jsonify({"success": False, "message": "Hospital not found"}), 404
    e = create_emergency(data)
    return jsonify({
        "success": True,
        "message": "Dispatched successfully to hospital console",
        "emergency": emergency_dict(e)
    })


# Admin
@app.route("/api/admin/reviews", methods=["GET"])
def admin_reviews():
    staff, error = admin_required()
    if error:
        return error
    q = ReviewModel.query
    status = (request.args.get("status") or "").lower()
    facility_type = (request.args.get("facility_type") or "").lower()
    if status in ("pending", "approved", "rejected", "hidden"):
        q = q.filter_by(status=status)
    if facility_type == "hospital":
        q = q.filter_by(facility_type=facility_type)
    facility_id = request.args.get("facility_id", type=int)
    if facility_id:
        q = q.filter_by(facility_id=facility_id)
    rows = q.order_by(ReviewModel.reported.desc(), ReviewModel.submitted_at.desc()).all()
    return jsonify([review_dict(r, include_moderation=True) for r in rows])


@app.route("/api/admin/reviews/<int:review_id>", methods=["PATCH"])
def admin_moderate_review(review_id):
    staff, error = admin_required()
    if error:
        return error
    row = db.session.get(ReviewModel, review_id)
    if not row:
        return jsonify({"success": False, "message": "Review not found"}), 404
    status = (request.get_json(silent=True) or {}).get("status")
    if status not in ("approved", "rejected", "hidden"):
        return jsonify({"success": False, "message": "Status must be approved, rejected, or hidden"}), 400
    row.status = status
    db.session.commit()
    return jsonify({"success": True, "review": review_dict(row, include_moderation=True)})


@app.route("/api/admin/sync", methods=["GET", "POST"])
def admin_sync():
    staff, error = admin_required()
    if error:
        return error
    record = db.session.get(SyncStatusModel, 1)
    if request.method == "POST":
        if not record:
            record = SyncStatusModel(id=1)
            db.session.add(record)
        record.last_sync_at = naive_now()
        db.session.commit()
    return jsonify({
        "success": True,
        "message": "RapidCare records refreshed. Hospital records were preserved.",
        "source": "RapidCare database",
        "external_feeds_connected": False,
        "last_sync_at": record.last_sync_at.replace(tzinfo=timezone.utc).isoformat() if record else None,
        "counts": {
            "hospitals": HospitalModel.query.count(),
            "ambulances": AmbulanceModel.query.count(),
            "emergencies": EmergencyModel.query.count(),
            "reviews_pending": ReviewModel.query.filter_by(status="pending").count(),
        },
    })


@app.route("/api/admin/stats", methods=["GET"])
def admin_stats():
    staff, error = admin_required()
    if error:
        return error
    hospitals = HospitalModel.query.all()
    return jsonify({
        "active_hospitals": sum(1 for h in hospitals if h.active),
        "ambulances_online": AmbulanceModel.query.filter(
            AmbulanceModel.status != "Offline",
            AmbulanceModel.updated_at >= naive_now() - timedelta(minutes=5),
            AmbulanceModel.lat.isnot(None),
            AmbulanceModel.lng.isnot(None)
        ).count(),
        "total_icu_beds": sum(h.icu_beds for h in hospitals),
        "dispatches_in_transit": EmergencyModel.query.filter(
            EmergencyModel.status.in_(IN_TRANSIT)
        ).count(),
    })


@app.route("/api/admin/hospitals", methods=["GET"])
def admin_hospitals():
    staff, error = admin_required()
    if error:
        return error
    return jsonify([
        hospital_admin_dict(h)
        for h in HospitalModel.query.order_by(HospitalModel.id)
    ])


@app.route("/api/admin/hospitals", methods=["POST"])
def admin_add_hospital():
    staff, error = admin_required()
    if error:
        return error
    d = request.get_json(silent=True) or {}
    if not d.get("name") or not d.get("location") or not d.get("phone"):
        return jsonify({"success": False, "message": "Hospital name, full address, and phone number are required."}), 400
    try:
        lat, lng = float(d.get("lat")), float(d.get("lng"))
        if not (-90 <= lat <= 90 and -180 <= lng <= 180):
            raise ValueError("Coordinates out of range")
        h = HospitalModel(
            name=d["name"].strip(), location=d["location"].strip(),
            phone=d["phone"].strip(),
            available_beds=int(d.get("general_beds", 0)),
            icu_beds=int(d.get("icu_beds", 0)),
            lat=lat, lng=lng,
            status="Listed",
            ed_status="Call to confirm",
            **{field: False for field in HOSPITAL_CAPABILITY_FIELDS},
        )
    except (TypeError, ValueError):
        return jsonify({"success": False, "message": "Enter a valid hospital phone, capacity, and map coordinate."}), 400
    db.session.add(h)
    db.session.commit()
    return jsonify({
        "success": True, "hospital": hospital_admin_dict(h)
    }), 201


@app.route("/api/admin/hospitals/<int:hid>", methods=["PATCH"])
def toggle_admin_hospital(hid):
    staff, error = admin_required()
    if error:
        return error
    h = db.session.get(HospitalModel, hid)
    if not h:
        return jsonify({"success": False, "message": "Hospital not found"}), 404
    data = request.get_json(silent=True) or {}
    if "lat" in data or "lng" in data:
        if ("lat" in data) != ("lng" in data):
            return jsonify({
                "success": False,
                "message": "Latitude and longitude must be provided together."
            }), 400
        try:
            lat, lng = float(data["lat"]), float(data["lng"])
        except (TypeError, ValueError):
            return jsonify({
                "success": False,
                "message": "Enter valid latitude and longitude coordinates."
            }), 400
        if not (
            math.isfinite(lat) and math.isfinite(lng)
            and -90 <= lat <= 90 and -180 <= lng <= 180
        ):
            return jsonify({
                "success": False,
                "message": "Coordinates must be within latitude -90 to 90 and longitude -180 to 180."
            }), 400
        h.lat, h.lng = lat, lng
        db.session.commit()
        return jsonify({
            "success": True, "hospital": hospital_admin_dict(h)
        })
    h.active = not h.active
    h.status = "Listed" if h.active else "Not listed"
    db.session.commit()
    return jsonify({
        "success": True, "status": h.status, "active": h.active
    })


@app.route("/api/admin/fleet", methods=["GET"])
def admin_fleet():
    staff, error = admin_required()
    if error:
        return error
    return jsonify([
        ambulance_dict(a)
        for a in AmbulanceModel.query.order_by(AmbulanceModel.id)
    ])


@app.route("/api/admin/fleet", methods=["POST"])
def admin_add_ambulance():
    staff, error = admin_required()
    if error:
        return error
    d = request.get_json(silent=True) or {}
    if not d.get("driver") or not d.get("vehicle_number"):
        return jsonify({
            "success": False,
            "message": "driver and vehicle_number required"
        }), 400
    a = AmbulanceModel(
        driver=d["driver"], vehicle_number=d["vehicle_number"],
        phone=d.get("phone", ""),
        type=d.get("type", "BLS (Basic Life Support)")
    )
    db.session.add(a)
    db.session.commit()
    return jsonify({
        "success": True, "ambulance": ambulance_dict(a)
    }), 201


@app.route("/api/admin/fleet/<int:aid>", methods=["PATCH"])
def admin_update_ambulance(aid):
    staff, error = admin_required()
    if error:
        return error
    a = db.session.get(AmbulanceModel, aid)
    if not a:
        return jsonify({"success": False, "message": "Ambulance not found"}), 404
    status = (request.get_json(silent=True) or {}).get("status")
    if status:
        a.status = status
        if status != "Offline":
            refresh_status(a)
        db.session.commit()
    return jsonify({"success": True, "ambulance": ambulance_dict(a)})


@app.route("/api/admin/emergencies", methods=["GET"])
def admin_emergencies():
    staff, error = admin_required()
    if error:
        return error
    # LIVE_CASE (not ACTIVE_CASE) so reached_hospital cases stay visible
    # while their ambulance is still associated with them.
    q = (
        EmergencyModel.query
        .filter(EmergencyModel.status.in_(LIVE_CASE))
        .order_by(EmergencyModel.id.desc())
    )
    return jsonify([emergency_dict(e) for e in q])


@app.route("/api/admin/dispatch-check", methods=["GET"])
def dispatch_check():
    staff, error = admin_required()
    if error:
        return error
    busy = busy_ids()
    out = []
    for a in AmbulanceModel.query.order_by(AmbulanceModel.id):
        age = gps_age(a)
        why = []
        if a.status == "Offline":
            why.append("set Offline")
        if age is None:
            why.append("no GPS received yet")
        elif age > 300:
            why.append(f"GPS is {round(age)}s old (driver app not sending)")
        if a.id in busy:
            why.append("already on a live case")
        out.append({
            "id": a.id, "vehicle_number": a.vehicle_number,
            "driver": a.driver, "status": a.status,
            "gps_age_seconds": round(age) if age is not None else None,
            "assignable": not why, "why_not": why
        })
    return jsonify(out)


@app.route("/api/admin/reset", methods=["POST"])
def admin_reset():
    staff, error = admin_required()
    if error:
        return error
    return jsonify({
        "success": False,
        "message": "Reset is disabled to protect facility records. Use Refresh Records to reload the shared directory."
    }), 410


if __name__ == "__main__":
    app.run(
        debug=os.environ.get("RAPIDCARE_DEBUG", "").strip().lower() in {"1", "true", "yes"},
        port=5000,
        # Allow a Flutter app on the same trusted Wi-Fi network to reach this dev server.
        host=os.environ.get("RAPIDCARE_HOST", "0.0.0.0")
    )
