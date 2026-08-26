class Hospital {
  final String id;
  final String name;
  final double distance; // in km
  final int availableBeds;
  final bool hasICU;
  final List<String> specialists;
  final int etaMinutes;
  final double rating;
  final int recommendationScore;
  final List<String> facilities;
  final String whyRecommended;
  final String phone;
  final String address;

  Hospital({
    required this.id,
    required this.name,
    required this.distance,
    required this.availableBeds,
    required this.hasICU,
    required this.specialists,
    required this.etaMinutes,
    this.rating = 4.5,
    this.recommendationScore = 95,
    this.facilities = const ['24/7 Emergency', 'Oxygen Support', 'Pharmacy'],
    this.whyRecommended = 'Shortest ETA and specialized trauma unit available.',
    this.phone = '+91 98765 43210',
    this.address = '123 Healthcare Ave, City Center',
  });
}
