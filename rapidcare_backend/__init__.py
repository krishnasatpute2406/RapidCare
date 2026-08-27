import os
from datetime import timedelta
from pathlib import Path

from flask import Flask, jsonify
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from sqlalchemy.exc import SQLAlchemyError

from .config import config
from .models import User, db


jwt = JWTManager()


def create_app(test_config=None):
    project_root = Path(__file__).resolve().parent.parent
    instance_dir = project_root / "instance"
    instance_dir.mkdir(parents=True, exist_ok=True)

    app = Flask(__name__, instance_path=str(instance_dir))

    # Test mode: callers must pass TESTING=True and provide DB URI and JWT secret in test_config
    if test_config and test_config.get('TESTING'):
        app.config.update(test_config)
        if not app.config.get('SQLALCHEMY_DATABASE_URI'):
            raise ValueError('TESTING mode requires SQLALCHEMY_DATABASE_URI in test_config')
        if not app.config.get('JWT_SECRET_KEY'):
            raise ValueError('TESTING mode requires JWT_SECRET_KEY in test_config')
    else:
        app.config.from_object(config)
        if not app.config.get('SQLALCHEMY_DATABASE_URI'):
            app.config['SQLALCHEMY_DATABASE_URI'] = config.SQLALCHEMY_DATABASE_URI
        jwt_secret = app.config.get('JWT_SECRET_KEY') or getattr(config, 'JWT_SECRET_KEY', None)
        if not jwt_secret:
            raise RuntimeError('JWT_SECRET_KEY is required in environment for non-test runs')
        app.config['JWT_SECRET_KEY'] = jwt_secret

    app.config['JWT_ACCESS_TOKEN_EXPIRES'] = app.config.get('JWT_ACCESS_TOKEN_EXPIRES', timedelta(hours=24))

    db.init_app(app)
    jwt.init_app(app)

    if app.config.get('TESTING'):
        cors_origins = app.config.get('CORS_ORIGINS', 'http://localhost:5000')
    else:
        cors_env = os.getenv('CORS_ORIGINS')
        cors_conf = getattr(config, 'CORS_ORIGINS', None)
        cors_origins = cors_env or cors_conf
        if not cors_origins:
            raise RuntimeError('CORS_ORIGINS environment variable or config.CORS_ORIGINS is required in non-test mode')
    if isinstance(cors_origins, str):
        cors_list = [o.strip() for o in cors_origins.split(',') if o.strip()]
    else:
        cors_list = list(cors_origins)
    CORS(app, resources={r"/api/*": {"origins": cors_list}})

    if app.config.get('TESTING'):
        with app.app_context():
            try:
                db.create_all()
            except SQLAlchemyError as exc:
                raise RuntimeError(f'Failed to initialize database: {exc}') from exc

    @app.route('/health')
    def health():
        return jsonify({'status': 'ok', 'service': 'rapidcare_backend'}), 200

    @app.route('/')
    def index():
        return jsonify({'message': 'Rapidcare API', 'status': 'ok'}), 200

    from .api import auth_bp
    from .api.bed_allocation import bp as bed_allocation_bp
    app.register_blueprint(auth_bp)
    app.register_blueprint(bed_allocation_bp)

    @jwt.user_lookup_loader
    def user_lookup_callback(_jwt_header, jwt_data):
        identity = jwt_data.get('sub')
        if identity is None:
            return None
        return User.query.get(int(identity))

    @jwt.user_lookup_error_loader
    def user_lookup_error_callback(_jwt_header, jwt_data):
        return jsonify({'error': 'user not found'}), 401

    return app
