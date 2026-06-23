class AttendanceRecord {
  final String id;
  final String sessionId;
  final String name;
  final String email;
  final String managerName;
  final String division;
  final DateTime submittedAt;
  final double userLat;
  final double userLng;
  final double distanceMeters;
  final String deviceFingerprint;

  const AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.email,
    required this.managerName,
    required this.division,
    required this.submittedAt,
    required this.userLat,
    required this.userLng,
    required this.distanceMeters,
    required this.deviceFingerprint,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        managerName: json['manager_name'] as String,
        division: json['division'] as String,
        submittedAt:
            DateTime.parse(json['submitted_at'] as String).toLocal(),
        userLat: (json['user_lat'] as num).toDouble(),
        userLng: (json['user_lng'] as num).toDouble(),
        distanceMeters: (json['distance_meters'] as num).toDouble(),
        deviceFingerprint: json['device_fingerprint'] as String,
      );

  Map<String, dynamic> toInsertJson() => {
        'session_id': sessionId,
        'name': name,
        'email': email,
        'manager_name': managerName,
        'division': division,
        'user_lat': userLat,
        'user_lng': userLng,
        'distance_meters': distanceMeters,
        'device_fingerprint': deviceFingerprint,
      };
}
