import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_record.dart';

enum AttendanceError {
  emailAlreadySubmitted,
  deviceAlreadySubmitted,
  unknown,
}

class AttendanceService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Returns all attendance records for a session, ordered newest first.
  static Future<List<AttendanceRecord>> getRecords(String sessionId) async {
    final data = await _db
        .from('attendance_records')
        .select()
        .eq('session_id', sessionId)
        .order('submitted_at', ascending: false);

    return (data as List<dynamic>)
        .map((json) => AttendanceRecord.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Submits an attendance record after checking for duplicates.
  /// Returns null on success, or an [AttendanceError] on failure.
  static Future<AttendanceError?> submit(AttendanceRecord record) async {
    // Check email duplicate
    final emailCheck = await _db
        .from('attendance_records')
        .select('id')
        .eq('session_id', record.sessionId)
        .eq('email', record.email.toLowerCase().trim());

    if ((emailCheck as List).isNotEmpty) {
      return AttendanceError.emailAlreadySubmitted;
    }

    // Check device fingerprint duplicate
    final deviceCheck = await _db
        .from('attendance_records')
        .select('id')
        .eq('session_id', record.sessionId)
        .eq('device_fingerprint', record.deviceFingerprint);

    if ((deviceCheck as List).isNotEmpty) {
      return AttendanceError.deviceAlreadySubmitted;
    }

    // Insert the record
    try {
      await _db.from('attendance_records').insert(record.toInsertJson());
      return null;
    } on PostgrestException {
      return AttendanceError.unknown;
    }
  }

  /// Returns a count of records for a session.
  static Future<int> getCount(String sessionId) async {
    final data = await _db
        .from('attendance_records')
        .select()
        .eq('session_id', sessionId)
        .count();
    return data.count;
  }
}
