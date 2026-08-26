from flask import Blueprint, current_app, request, jsonify
from ..models import create_ambulance_request, list_ambulance_requests

bp = Blueprint('ambulance', __name__)


@bp.route('/request', methods=['POST'])
def request_ambulance():
    data = request.get_json() or {}
    patient_name = data.get('patient_name')
    pickup_address = data.get('pickup_address')
    severity = data.get('severity', 'normal')

    if not patient_name or not pickup_address:
        return jsonify({'error': 'patient_name and pickup_address are required'}), 400

    req_id = create_ambulance_request(current_app.config['DATABASE'], patient_name, pickup_address, severity)
    return jsonify({'message': 'ambulance requested', 'request_id': req_id}), 201


@bp.route('/requests', methods=['GET'])
def list_requests():
    rows = list_ambulance_requests(current_app.config['DATABASE'])
    return jsonify({'requests': rows})
