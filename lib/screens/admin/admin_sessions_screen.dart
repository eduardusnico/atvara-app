import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/session.dart';
import '../../router.dart';
import '../../services/session_service.dart';
import '../../theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';

class AdminSessionsScreen extends StatefulWidget {
  const AdminSessionsScreen({super.key});

  @override
  State<AdminSessionsScreen> createState() => _AdminSessionsScreenState();
}

class _AdminSessionsScreenState extends State<AdminSessionsScreen> {
  List<Session> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await SessionService.getAllSessions();
      if (mounted) setState(() => _sessions = sessions);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteSession(Session session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text(
          'Delete "${session.name}"? All attendance records will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SessionService.deleteSession(session.id);
      _load();
    }
  }

  Future<void> _toggleActive(Session session) async {
    await SessionService.setActive(session.id, active: !session.isActive);
    _load();
  }

  void _logout() {
    adminAuthNotifier.value = false;
    context.go('/admin');
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  int get _openCount =>
      _sessions.where((s) => s.status == SessionStatus.open).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? _buildError()
          : _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.fingerprint, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Atvara Admin'),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => context.go('/admin/companies'),
          icon: const Icon(Icons.business),
          tooltip: 'Manage Companies',
        ),
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
        IconButton(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          Text(
            'Failed to load sessions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(_error!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sessions',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          'Manage attendance sessions',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  GradientButton(
                    label: 'New Session',
                    icon: Icons.add,
                    width: 160,
                    height: 44,
                    onPressed: () => context.go('/admin/sessions/new'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Total Sessions',
                      '${_sessions.length}',
                      Icons.event_note,
                      AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      'Open Now',
                      '$_openCount',
                      Icons.check_circle,
                      AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Sessions list
              if (_sessions.isEmpty)
                GlassCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.event_busy,
                        color: AppColors.textMuted,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No sessions yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first attendance session to get started.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      GradientButton(
                        label: 'Create Session',
                        icon: Icons.add,
                        width: 200,
                        onPressed: () => context.go('/admin/sessions/new'),
                      ),
                    ],
                  ),
                )
              else
                ..._sessions.map((s) => _buildSessionCard(s)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Session session) {
    final status = session.status;
    final statusColor = switch (status) {
      SessionStatus.open => AppColors.success,
      SessionStatus.upcoming => AppColors.primary,
      SessionStatus.closed => AppColors.textMuted,
      SessionStatus.inactive => AppColors.error,
    };
    final fmt = DateFormat('MMM dd • HH:mm');

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusBadge(status.label, statusColor),
                        const SizedBox(width: 8),
                        _statusBadge(
                          session.attendanceMode.label,
                          _modeColor(session.attendanceMode),
                        ),
                      ],
                    ),
                    if (session.description != null &&
                        session.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        session.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoChip(
                Icons.schedule,
                '${fmt.format(session.startTime)} – ${DateFormat('HH:mm').format(session.endTime)}',
              ),
              const SizedBox(width: 12),
              _infoChip(Icons.people, '${session.attendeeCount} attendees'),
              if (session.attendanceMode != AttendanceMode.online) ...[
                const SizedBox(width: 12),
                _infoChip(Icons.radar, '${session.radiusMeters}m radius'),
              ],
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => context.go('/admin/sessions/${session.id}'),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _toggleActive(session),
                icon: Icon(
                  session.isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  size: 16,
                ),
                label: Text(session.isActive ? 'Deactivate' : 'Activate'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _deleteSession(session),
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.error.withAlpha(200),
                tooltip: 'Delete session',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Color _modeColor(AttendanceMode mode) {
    return switch (mode) {
      AttendanceMode.offline => AppColors.primary,
      AttendanceMode.online => AppColors.success,
      AttendanceMode.hybrid => AppColors.warning,
    };
  }
}
