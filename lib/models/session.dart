enum AttendanceMode { offline, online, hybrid }

extension AttendanceModeExtension on AttendanceMode {
  String get value {
    switch (this) {
      case AttendanceMode.offline:
        return 'offline';
      case AttendanceMode.online:
        return 'online';
      case AttendanceMode.hybrid:
        return 'hybrid';
    }
  }

  String get label {
    switch (this) {
      case AttendanceMode.offline:
        return 'Offline';
      case AttendanceMode.online:
        return 'Online';
      case AttendanceMode.hybrid:
        return 'Hybrid';
    }
  }

  static AttendanceMode fromString(String? value) {
    switch (value) {
      case 'online':
        return AttendanceMode.online;
      case 'hybrid':
        return AttendanceMode.hybrid;
      default:
        return AttendanceMode.offline;
    }
  }
}

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
  final AttendanceMode attendanceMode;

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
    this.attendanceMode = AttendanceMode.offline,
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
        attendanceMode: AttendanceModeExtension.fromString(
          json['attendance_mode'] as String?,
        ),
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
        'attendance_mode': attendanceMode.value,
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
