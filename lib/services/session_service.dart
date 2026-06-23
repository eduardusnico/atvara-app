import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import '../models/session.dart';

class SessionService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Fetches a single session by ID. Returns null if not found.
  static Future<Session?> getSession(String sessionId) async {
    try {
      final data = await _db
          .from('sessions')
          .select()
          .eq('id', sessionId)
          .single();
      return Session.fromJson(data);
    } on PostgrestException catch (e) {
      // PGRST116 = no rows found
      if (e.code == 'PGRST116') return null;
      rethrow;
    }
  }

  /// Fetches all sessions with attendee count for the admin dashboard.
  static Future<List<Session>> getAllSessions() async {
    final data = await _db
        .from('sessions')
        .select('*, attendance_records(count)')
        .order('created_at', ascending: false);

    return (data as List<dynamic>).map((json) {
      final records = json['attendance_records'] as List<dynamic>? ?? [];
      final count = records.isNotEmpty
          ? (records.first as Map<String, dynamic>)['count'] as int? ?? 0
          : 0;
      return Session.fromJson({
        ...json as Map<String, dynamic>,
        'attendee_count': count,
      });
    }).toList();
  }

  /// Creates a new session and returns the inserted record.
  static Future<Session> createSession(Session session) async {
    final data = await _db
        .from('sessions')
        .insert(session.toInsertJson())
        .select()
        .single();
    return Session.fromJson(data);
  }

  /// Toggles the active status of a session.
  static Future<void> setActive(
    String sessionId, {
    required bool active,
  }) async {
    await _db
        .from('sessions')
        .update({'is_active': active})
        .eq('id', sessionId);
  }

  /// Deletes a session and all its attendance records (cascade).
  static Future<void> deleteSession(String sessionId) async {
    await _db.from('sessions').delete().eq('id', sessionId);
  }
}
