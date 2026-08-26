import os
from flask import Flask
from flask_cors import CORS
from . import models


def create_app(test_config=None):
    app = Flask(__name__, instance_relative_config=False)

    # Load configuration
    app.config.from_mapping(
        SECRET_KEY=os.environ.get('SECRET_KEY', 'change-me-in-production'),
        DATABASE=os.path.join(app.root_path, 'rapidcare.db')
    )

    if test_config:
        app.config.update(test_config)

    CORS(app)

    # Initialize database
    with app.app_context():
        models.init_db(app.config['DATABASE'])

    # Register blueprints
    from .api import auth, hospitals, ambulance
    app.register_blueprint(auth.bp)
    app.register_blueprint(hospitals.bp, url_prefix='/hospitals')
    app.register_blueprint(ambulance.bp, url_prefix='/ambulance')

    @app.route('/')
    def index():
        return {'message': 'Rapidcare API', 'status': 'ok'}

    return app
