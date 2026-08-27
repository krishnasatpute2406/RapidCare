from __future__ import annotations

import bcrypt
from datetime import datetime
from enum import Enum

from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import CheckConstraint, UniqueConstraint
from sqlalchemy.orm import validates


db = SQLAlchemy()


class UserRole(str, Enum):
    PATIENT = 'patient'
    DRIVER = 'driver'
    HOSPITAL = 'hospital'
    ADMIN = 'admin'


class User(db.Model):
    __tablename__ = 'users'
    __table_args__ = (
        UniqueConstraint('email', name='uq_users_email'),
        CheckConstraint("role IN ('patient', 'driver', 'hospital', 'admin')", name='ck_users_role'),
    )

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    email = db.Column(db.String(255), nullable=False, index=True)
    phone = db.Column(db.String(30), nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.Enum(UserRole, values_callable=lambda x: [r.value for r in UserRole]), nullable=False, default=UserRole.PATIENT.value)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

    @validates('email')
    def validate_email(self, key, value):
        if not value:
            raise ValueError('Email is required')
        return value.lower().strip()

    @validates('role')
    def validate_role(self, key, value):
        if value not in {role.value for role in UserRole}:
            raise ValueError(f'Invalid role: {value}')
        return value

    def set_password(self, password: str) -> None:
        self.password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    def check_password(self, password: str) -> bool:
        return bcrypt.checkpw(password.encode('utf-8'), self.password_hash.encode('utf-8'))

    def to_public_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'email': self.email,
            'phone': self.phone,
            'role': self.role,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }


class HospitalBedInventory(db.Model):
    __tablename__ = 'hospital_bed_inventory'
    __table_args__ = (
        UniqueConstraint('hospital_id', 'bed_type', name='uq_hospital_bed_type'),
        CheckConstraint('total_beds >= 0', name='ck_total_beds_non_negative'),
        CheckConstraint('available_beds >= 0', name='ck_available_beds_non_negative'),
        CheckConstraint('available_beds <= total_beds', name='ck_available_beds_within_total'),
    )

    id = db.Column(db.Integer, primary_key=True)
    hospital_id = db.Column(db.Integer, nullable=False, index=True)
    bed_type = db.Column(db.String(20), nullable=False, default='general')
    total_beds = db.Column(db.Integer, nullable=False, default=0)
    available_beds = db.Column(db.Integer, nullable=False, default=0)
    updated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)


class BedAllocation(db.Model):
    __tablename__ = 'bed_allocations'

    id = db.Column(db.Integer, primary_key=True)
    hospital_id = db.Column(db.Integer, nullable=False, index=True)
    patient_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    bed_type = db.Column(db.String(20), nullable=False)
    emergency_request_id = db.Column(db.String(64), nullable=True, unique=True)
    status = db.Column(db.String(20), nullable=False, default='allocated')
    allocated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
