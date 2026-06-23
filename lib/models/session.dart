class Session {
  final String id;
  final String name;
  final String? description;
  final double targetLat;
  final double targetLng;
  final int radiusMeters;
  final DateTime startTime;
  final DateTime endTime;
  final bool isActive;
  final DateTime createdAt;
  final int attendeeCount;

  const Session({
    required this.id,
    required this.name,
    this.description,
    required this.targetLat,
    required this.targetLng,
    required this.radiusMeters,
    required this.startTime,
    required this.endTime,
    required this.isActive,
    required this.createdAt,
    this.attendeeCount = 0,
  });

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        targetLat: (json['target_lat'] as num).toDouble(),
        targetLng: (json['target_lng'] as num).toDouble(),
        radiusMeters: json['radius_meters'] as int,
        startTime: DateTime.parse(json['start_time'] as String).toLocal(),
        endTime: DateTime.parse(json['end_time'] as String).toLocal(),
        isActive: json['is_active'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        attendeeCount: json['attendee_count'] as int? ?? 0,
      );

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'description': description,
        'target_lat': targetLat,
        'target_lng': targetLng,
        'radius_meters': radiusMeters,
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'is_active': isActive,
      };

  SessionStatus get status {
    final now = DateTime.now();
    if (!isActive) return SessionStatus.inactive;
    if (now.isBefore(startTime)) return SessionStatus.upcoming;
    if (now.isAfter(endTime)) return SessionStatus.closed;
    return SessionStatus.open;
  }
}

enum SessionStatus { open, upcoming, closed, inactive }

extension SessionStatusLabel on SessionStatus {
  String get label {
    switch (this) {
      case SessionStatus.open:
        return 'Open';
      case SessionStatus.upcoming:
        return 'Upcoming';
      case SessionStatus.closed:
        return 'Closed';
      case SessionStatus.inactive:
        return 'Inactive';
    }
  }
}
