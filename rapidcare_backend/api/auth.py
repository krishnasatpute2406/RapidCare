from flask import Blueprint, jsonify, request
from flask_jwt_extended import create_access_token, jwt_required, current_user
from ..models import User, UserRole, db
from .decorators import role_required

bp = Blueprint('auth', __name__, url_prefix='/api/auth')


@bp.route('/register', methods=['POST'])
def register():
    data = request.get_json(silent=True) or {}
    name = (data.get('name') or '').strip()
    email = (data.get('email') or '').strip().lower()
    phone = (data.get('phone') or '').strip()
    password = data.get('password') or ''

    if not name or not email or not phone or not password:
        return jsonify({'success': False, 'message': 'name, email, phone and password are required'}), 400

    if User.query.filter_by(email=email).first():
        return jsonify({'success': False, 'message': 'email already registered'}), 409

    user = User(name=name, email=email, phone=phone, role=UserRole.PATIENT.value)
    user.set_password(password)
    db.session.add(user)
    db.session.commit()

    token = create_access_token(identity=str(user.id), additional_claims={'role': user.role, 'name': user.name})

    return jsonify({
        'success': True,
        'message': 'patient registration successful',
        'access_token': token,
        'user': {'id': user.id, 'name': user.name, 'email': user.email, 'role': user.role}
    }), 201


@bp.route('/login', methods=['POST'])
def login():
    data = request.get_json(silent=True) or {}
    email = (data.get('email') or '').strip().lower()
    password = data.get('password') or ''

    if not email or not password:
        return jsonify({'success': False, 'message': 'email and password are required'}), 400

    user = User.query.filter_by(email=email).first()
    if not user or not user.check_password(password):
        return jsonify({'success': False, 'message': 'invalid email or password'}), 401

    token = create_access_token(identity=str(user.id), additional_claims={'role': user.role, 'name': user.name})

    return jsonify({
        'success': True,
        'message': 'login successful',
        'access_token': token,
        'user': {'id': user.id, 'name': user.name, 'email': user.email, 'role': user.role}
    }), 200


@bp.route('/me', methods=['GET'])
@jwt_required()
def me():
    user = User.query.get(int(current_user.id))
    if not user:
        return jsonify({'success': False, 'message': 'user not found'}), 404
    return jsonify({'success': True, 'user': user.to_public_dict()}), 200


@bp.route('/admin-only', methods=['GET'])
@jwt_required()
@role_required('admin')
def admin_only():
    return jsonify({'success': True, 'message': 'admin access granted'}), 200
