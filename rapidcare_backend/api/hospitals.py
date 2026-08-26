from flask import Blueprint, current_app, jsonify
from ..models import list_hospitals

bp = Blueprint('hospitals', __name__)


@bp.route('/', methods=['GET'])
def get_hospitals():
    hospitals = list_hospitals(current_app.config['DATABASE'])
    return jsonify({'hospitals': hospitals})


@bp.route('/<int:hospital_id>', methods=['GET'])
def get_hospital(hospital_id):
    hospitals = list_hospitals(current_app.config['DATABASE'])
    for h in hospitals:
        if h.get('id') == hospital_id:
            return jsonify({'hospital': h})
    return jsonify({'error': 'not found'}), 404
