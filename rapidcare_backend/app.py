import os

from rapidcare_backend import create_app
from rapidcare_backend.models import db

app = create_app()

with app.app_context():
    db.create_all()

if __name__ == '__main__':
    app.run(
        host=os.getenv('FLASK_HOST', '0.0.0.0'),
        port=int(os.getenv('FLASK_PORT', '5000')),
        debug=os.getenv('FLASK_DEBUG', 'false').lower() in {'1', 'true', 'yes'},
    )
