from flask import Blueprint, jsonify, request
from flask_jwt_extended import current_user, jwt_required
from sqlalchemy.exc import IntegrityError

from ..models import BedAllocation, HospitalBedInventory, db


bp = Blueprint('bed_allocation', __name__, url_prefix='/api/hospitals')
ALLOWED_BED_TYPES = {'general', 'icu'}


@bp.route('/<int:hospital_id>/allocate-bed', methods=['POST'])
@jwt_required()
def allocate_bed(hospital_id):
    data = request.get_json(silent=True) or {}
    bed_type = (data.get('bed_type') or 'general').strip().lower()
    emergency_request_id = data.get('emergency_request_id')

    if bed_type not in ALLOWED_BED_TYPES:
        return jsonify({'success': False, 'message': 'bed_type must be general or icu'}), 400
    if emergency_request_id is not None:
        if not isinstance(emergency_request_id, str) or not emergency_request_id.strip():
            return jsonify({'success': False, 'message': 'emergency_request_id must be a non-empty string'}), 400
        emergency_request_id = emergency_request_id.strip()

    if emergency_request_id:
        existing = BedAllocation.query.filter_by(emergency_request_id=emergency_request_id).first()
        if existing:
            return jsonify({'success': True, 'allocation': _allocation_response(existing)}), 200

    inventory = HospitalBedInventory.query.filter_by(
        hospital_id=hospital_id,
        bed_type=bed_type,
    ).with_for_update().first()
    if inventory is None:
        return jsonify({'success': False, 'message': 'bed inventory not found'}), 404
    if inventory.available_beds < 1:
        return jsonify({'success': False, 'message': f'no {bed_type} beds available'}), 409

    allocation = BedAllocation(
        hospital_id=hospital_id,
        patient_id=current_user.id,
        bed_type=bed_type,
        emergency_request_id=emergency_request_id,
    )
    inventory.available_beds -= 1
    db.session.add(allocation)
    try:
        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        return jsonify({'success': False, 'message': 'allocation request already exists'}), 409

    return jsonify({'success': True, 'allocation': _allocation_response(allocation)}), 201


def _allocation_response(allocation):
    return {
        'id': allocation.id,
        'hospital_id': allocation.hospital_id,
        'patient_id': allocation.patient_id,
        'bed_type': allocation.bed_type,
        'emergency_request_id': allocation.emergency_request_id,
        'status': allocation.status,
        'allocated_at': allocation.allocated_at.isoformat(),
    }