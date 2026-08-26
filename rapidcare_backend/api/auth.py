from flask import Blueprint, request, current_app, jsonify
from werkzeug.security import check_password_hash
import jwt
from datetime import datetime, timedelta
from ..models import create_user, find_user_by_email

bp = Blueprint('auth', __name__)


@bp.route('/register', methods=['POST'])
def register():
    data = request.get_json() or {}
    email = (data.get('email') or '').strip().lower()
    full_name = data.get('full_name') or ''
    password = data.get('password') or ''

    if not email or not full_name or not password:
        return jsonify({'error': 'email, full_name and password are required'}), 400

    created = create_user(current_app.config['DATABASE'], email, full_name, password)
    if created:
        return jsonify({'message': 'user created', 'id': created}), 201
    return jsonify({'error': 'user could not be created (maybe exists)'}), 400


@bp.route('/login', methods=['POST'])
def login():
    data = request.get_json() or {}
    email = (data.get('email') or '').strip().lower()
    password = data.get('password') or ''

    if not email or not password:
        return jsonify({'error': 'email and password are required'}), 400

    user = find_user_by_email(current_app.config['DATABASE'], email)
    if user is None or not check_password_hash(user['password'], password):
        return jsonify({'error': 'invalid email or password'}), 401

    token = jwt.encode(
        {
            'user_id': user['id'],
            'email': user['email'],
            'role': user['role'],
            'exp': datetime.utcnow() + timedelta(hours=12)
        },
        current_app.config['SECRET_KEY'],
        algorithm='HS256'
    )

    return jsonify({'message': 'login successful', 'access_token': token, 'user': {'id': user['id'], 'email': user['email'], 'full_name': user['full_name'], 'role': user['role']}})
