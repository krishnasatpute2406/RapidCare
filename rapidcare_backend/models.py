import sqlite3
from werkzeug.security import generate_password_hash, check_password_hash


def get_db_connection(db_path):
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


def init_db(db_path):
    conn = get_db_connection(db_path)
    cur = conn.cursor()

    cur.execute('''
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        full_name TEXT NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'user',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    ''')

    cur.execute('''
    CREATE TABLE IF NOT EXISTS hospitals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        latitude REAL,
        longitude REAL
    )
    ''')

    cur.execute('''
    CREATE TABLE IF NOT EXISTS ambulance_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_name TEXT NOT NULL,
        pickup_address TEXT NOT NULL,
        severity TEXT,
        status TEXT DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    ''')

    # Seed a sample hospital if table empty
    cur.execute('SELECT COUNT(1) as c FROM hospitals')
    row = cur.fetchone()
    if row and row[0] == 0:
        cur.execute('INSERT INTO hospitals (name, address, phone, latitude, longitude) VALUES (?, ?, ?, ?, ?)',
                    ('City General Hospital', '123 Main St', '+1-555-1234', 12.9716, 77.5946))

    conn.commit()
    conn.close()


def create_user(db_path, email, full_name, password, role='user'):
    conn = get_db_connection(db_path)
    cur = conn.cursor()
    hashed = generate_password_hash(password)
    try:
        cur.execute('INSERT INTO users (email, full_name, password, role) VALUES (?, ?, ?, ?)',
                    (email, full_name, hashed, role))
        conn.commit()
        user_id = cur.lastrowid
    except Exception:
        user_id = None
    conn.close()
    return user_id


def find_user_by_email(db_path, email):
    conn = get_db_connection(db_path)
    user = conn.execute('SELECT * FROM users WHERE email = ?', (email,)).fetchone()
    conn.close()
    return user


def list_hospitals(db_path):
    conn = get_db_connection(db_path)
    rows = conn.execute('SELECT * FROM hospitals').fetchall()
    conn.close()
    return [dict(r) for r in rows]


def create_ambulance_request(db_path, patient_name, pickup_address, severity):
    conn = get_db_connection(db_path)
    cur = conn.cursor()
    cur.execute('INSERT INTO ambulance_requests (patient_name, pickup_address, severity) VALUES (?, ?, ?)',
                (patient_name, pickup_address, severity))
    conn.commit()
    req_id = cur.lastrowid
    conn.close()
    return req_id


def list_ambulance_requests(db_path):
    conn = get_db_connection(db_path)
    rows = conn.execute('SELECT * FROM ambulance_requests ORDER BY created_at DESC').fetchall()
    conn.close()
    return [dict(r) for r in rows]
