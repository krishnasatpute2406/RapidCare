import 'package:flutter/material.dart';

import '../../services/api.dart';

/// Shared Patient and Driver review sheet for a directory hospital.
Future<void> showFacilityReviews(
  BuildContext context, {
  required int facilityId,
  required String facilityName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FacilityReviewsSheet(
      facilityId: facilityId,
      facilityName: facilityName,
    ),
  );
}

class FacilityReviewsSheet extends StatefulWidget {
  const FacilityReviewsSheet({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  final int facilityId;
  final String facilityName;

  @override
  State<FacilityReviewsSheet> createState() => _FacilityReviewsSheetState();
}

class _FacilityReviewsSheetState extends State<FacilityReviewsSheet> {
  final _comment = TextEditingController();
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true, _sending = false;
  int _rating = 0;
  String? _error, _notice;
  double? _average;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await api('/api/app/reviews?facility_type=hospital&facility_id=${widget.facilityId}');
      if (!mounted) return;
      setState(() {
        _reviews = (result['reviews'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _average = (result['rating'] as num?)?.toDouble();
        _count = (result['review_count'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Could not load reviews: $e'; });
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Choose a star rating first.');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      await api('/api/app/reviews', method: 'POST', body: {
        'facility_type': 'hospital',
        'facility_id': widget.facilityId,
        'rating': _rating,
        'comment': _comment.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _notice = 'Thanks. Your review is pending Admin moderation and will appear after approval.';
        _rating = 0;
        _comment.clear();
        _sending = false;
      });
    } catch (e) {
      if (mounted) setState(() { _sending = false; _error = 'Could not submit review: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(top: 40, bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .88),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: SafeArea(
          top: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(children: [
                const Icon(Icons.star_rounded, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.facilityName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
            ),
            Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
              Text(_average == null ? 'No approved ratings yet' : '${_average!.toStringAsFixed(1)} / 5  ·  $_count approved ${_count == 1 ? 'review' : 'reviews'}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF00796B))),
              const SizedBox(height: 10),
              if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
              else if (_error != null && _reviews.isEmpty) Text(_error!, style: const TextStyle(color: Colors.red))
              else if (_reviews.isEmpty) const Text('No approved comments yet. You can be the first to leave a review.', style: TextStyle(color: Colors.black54))
              else ..._reviews.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF5F8F7), borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${List.filled((r['rating'] as num?)?.toInt() ?? 0, '★').join()}${List.filled(5 - ((r['rating'] as num?)?.toInt() ?? 0), '☆').join()}', style: const TextStyle(color: Colors.amber, fontSize: 17)),
                  if ((r['comment'] ?? '').toString().isNotEmpty) ...[const SizedBox(height: 4), Text(r['comment'].toString())],
                ]),
              )),
              const Divider(height: 28),
              const Text('Leave an honest review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 5),
              const Text('Reviews are checked by RapidCare Admin before appearing.', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 7),
              Row(children: List.generate(5, (i) => IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _sending ? null : () => setState(() { _rating = i + 1; _error = null; }),
                icon: Icon(i < _rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 30),
              ))),
              TextField(controller: _comment, maxLength: 1200, maxLines: 3, decoration: const InputDecoration(labelText: 'Comment (optional)', border: OutlineInputBorder(), alignLabelWithHint: true)),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
              if (_notice != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_notice!, style: const TextStyle(color: Color(0xFF00796B), fontSize: 12))),
              const SizedBox(height: 10),
              FilledButton(onPressed: _sending ? null : _submit, child: Text(_sending ? 'Submitting…' : 'Submit for review')),
            ])),
          ]),
        ),
      ),
    );
  }
}
