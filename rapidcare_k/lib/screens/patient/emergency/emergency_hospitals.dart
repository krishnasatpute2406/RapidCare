import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../services/api.dart';

const _red = Color(0xFFD32F2F);

// What each emergency type needs: [specialist, facility]. Names match the hospital portal.
const _needs = {
  'cardiac': ['Cardiologist', '24x7 Cath Lab'],
  'burn': ['Plastic & Burn Surgeon', 'Burn Isolation Ward'],
  'trauma': ['Orthopaedic', 'Emergency Physician'],
  'accident': ['Orthopaedic', 'Emergency Physician'],
  'pregnancy': ['Obstetrician & Gynecologist', 'maternity_ot'],
  'other': ['Emergency Physician', 'CT / MRI'],
};

class EmergencyHospitalsScreen extends StatefulWidget {
  final String emergencyType;
  final LatLng? patient; // confirmed GPS position from step 1
  final ValueChanged<Map<String, dynamic>> onHospitalSelected; // the whole hospital (id, name, lat, lng…)
  final VoidCallback onBack;

  const EmergencyHospitalsScreen({
    super.key,
    required this.emergencyType,
    required this.onHospitalSelected,
    required this.onBack,
    this.patient,
  });

  @override
  State<EmergencyHospitalsScreen> createState() => _EmergencyHospitalsScreenState();
}

class _EmergencyHospitalsScreenState extends State<EmergencyHospitalsScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _dot =
  AnimationController(duration: const Duration(milliseconds: 800), vsync: this)..repeat(reverse: true);
  List<Map<String, dynamic>> _h = [];
  bool _loading = true;
  bool _requestInFlight = false;
  String? _err;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true)); // beds change live
  }

  @override
  void dispose() {
    _t?.cancel();
    _dot.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!mounted || _requestInFlight) return;
    _requestInFlight = true;
    if (!silent) setState(() { _loading = true; _err = null; });
    try {
      final p = widget.patient;
      final r = await api('/api/app/hospitals?type=${widget.emergencyType.toLowerCase()}'
          '${p != null ? '&lat=${p.latitude}&lng=${p.longitude}' : ''}') as List;
      if (!mounted) return;
      final hospitals = r.map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        _h = hospitals;
        _loading = false;
        _err = null;
      });
    } catch (_) {
      if (mounted && (!silent || _h.isEmpty)) {
        setState(() {
          _loading = false;
          _err = 'RapidCare may take about a minute to wake after inactivity. If you need immediate help, call 108.';
        });
      }
    } finally {
      _requestInFlight = false;
    }
  }

  List<Widget> _why(Map<String, dynamic> h) {
    final need = _needs[widget.emergencyType.toLowerCase()] ?? _needs['other']!;
    final spec = (h['specialists'] as Map?) ?? {}, fac = (h['facilities'] as Map?) ?? {}, units = (h['units'] as Map?) ?? {};
    final serviceMatch = need[1] == 'maternity_ot'
        ? units['maternity_ot'] == true
        : need[1] == 'Emergency Physician'
            ? spec['Emergency Physician'] == true
            : fac[need[1]] == true;
    final specialistMatch = spec[need[0]] == true;
    final matches = (specialistMatch ? 1 : 0) + (serviceMatch ? 1 : 0);
    final serviceLabel = need[1] == 'maternity_ot' ? 'Maternity OT' : need[1];
    return [
      if (h['distance_km'] != null) _bullet('About ${h['distance_km']} km away (straight-line distance)'),
      if (specialistMatch) _bullet('${need[0]} listed'),
      if (serviceMatch) _bullet('$serviceLabel listed'),
      if (!specialistMatch) _bullet('${need[0]} not confirmed in the directory', warn: true),
      if (!serviceMatch) _bullet('$serviceLabel not confirmed in the directory', warn: true),
      if (matches == 1) _bullet('Only one of the two required capabilities is confirmed; call to verify', warn: true),
      if (h['distance_km'] == null) _bullet('Distance unavailable; ordered by listed capabilities', warn: true),
      _bullet('Call to confirm emergency acceptance and capacity', warn: true),
    ];
  }

  int _matchCount(Map<String, dynamic> h) {
    final reported = h['capability_matches'];
    if (reported is num) return reported.toInt();
    final need = _needs[widget.emergencyType.toLowerCase()] ?? _needs['other']!;
    final specialists = (h['specialists'] as Map?) ?? {};
    final facilities = (h['facilities'] as Map?) ?? {};
    final units = (h['units'] as Map?) ?? {};
    final hasService = need[1] == 'maternity_ot'
        ? units['maternity_ot'] == true
        : need[1] == 'Emergency Physician'
            ? specialists['Emergency Physician'] == true
            : facilities[need[1]] == true;
    return (specialists[need[0]] == true ? 1 : 0) + (hasService ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: _red,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              FadeTransition(
                opacity: _dot,
                child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              ),
              const SizedBox(width: 6),
              const Text('EMERGENCY ASSISTANCE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 2),
            const Text('Step 3 of 5', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
          OutlinedButton(
            onPressed: widget.onBack,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white70),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: const Text('Back', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Recommended Hospitals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text('Shared hospital directory', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(
              widget.patient == null
      ? 'Ranked by listed emergency capabilities. Allow GPS to include distance; call to confirm availability.'
              : 'Ranked by listed emergency fit and straight-line distance; call to confirm availability.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
            else if (_err != null && _h.isEmpty)
              Column(children: [
                Text(_err!, style: const TextStyle(color: _red)),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _load, child: const Text('Retry')),
              ])
            else if (_h.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('No hospitals are accepting emergencies right now. Call 108.', style: TextStyle(color: Colors.grey))),
                )
              else
                ...List.generate(_h.length, (i) => _card(_h[i], i == 0)),
          ]),
        ),
      ),
    ]);
  }

  Widget _card(Map<String, dynamic> h, bool top) {
    final matches = _matchCount(h);
    final hasDistance = h['distance_km'] != null;
    final badge = matches == 2
        ? 'BEST LISTED FIT'
        : matches == 1
            ? 'PARTIAL LISTED FIT'
            : hasDistance
                ? 'CLOSEST LISTED'
                : 'DIRECTORY LISTING';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: top ? _red : Colors.grey.shade300, width: top ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          top
              ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(4)),
            child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          )
              : const SizedBox.shrink(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(h['eta_min'] != null ? 'ETA: ~${h['eta_min']} min' : 'ETA: —', style: const TextStyle(color: _red, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(h['distance_km'] != null ? '${h['distance_km']} km' : '', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('${h['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87))),
          if (h['rating'] != null) ...[
            const Icon(Icons.star, color: Colors.amber, size: 15),
            Text('${h['rating']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ]),
        const SizedBox(height: 2),
            Text('${h['location'] ?? ''}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const Divider(height: 16),
        const Text('Why Recommended:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 4),
        ..._why(h),
        const Divider(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(
            child: Text('Listed: ${h['available_beds']} beds • ${h['icu_beds']} ICU',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
          ),
          TextButton(
            onPressed: () => widget.onHospitalSelected(h),
            child: const Text('Select >', style: TextStyle(color: _red, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ]),
      ]),
    );
  }

  Widget _bullet(String text, {bool warn = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(children: [
      Icon(warn ? Icons.warning_amber_rounded : Icons.check, size: 12, color: warn ? Colors.orange : _red),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: warn ? Colors.orange.shade800 : Colors.grey.shade700))),
    ]),
  );
}
