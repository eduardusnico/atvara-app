import 'dart:convert';
import 'dart:html' as html;
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sizer/sizer.dart';
import '../../models/attendance_record.dart';
import '../../models/session.dart';
import '../../services/attendance_service.dart';
import '../../services/session_service.dart';
import '../../theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';

class AdminSessionDetailScreen extends StatefulWidget {
  final String sessionId;
  const AdminSessionDetailScreen({super.key, required this.sessionId});
  @override
  State<AdminSessionDetailScreen> createState() =>
      _AdminSessionDetailScreenState();
}

class _AdminSessionDetailScreenState extends State<AdminSessionDetailScreen> {
  Session? _session;
  List<AttendanceRecord> _records = [];
  List<AttendanceRecord> _filteredRecords = [];
  bool _loadingSession = true;
  bool _loadingRecords = true;
  String? _error;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadSession();
    if (_session != null) {
      await _loadRecords();
    }
  }

  Future<void> _loadSession() async {
    setState(() {
      _loadingSession = true;
      _error = null;
    });
    try {
      final session = await SessionService.getSession(widget.sessionId);
      if (mounted) {
        setState(() {
          _session = session;
          _loadingSession = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load session details: $e';
          _loadingSession = false;
        });
      }
    }
  }

  Future<void> _loadRecords() async {
    setState(() {
      _loadingRecords = true;
    });
    try {
      final records = await AttendanceService.getRecords(widget.sessionId);
      if (mounted) {
        setState(() {
          _records = records;
          _applyFilter();
          _loadingRecords = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load attendance records: $e';
          _loadingRecords = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchCtrl.text.toLowerCase().trim();
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredRecords = List.from(_records);
    } else {
      _filteredRecords = _records.where((r) {
        return r.name.toLowerCase().contains(_searchQuery) ||
            r.email.toLowerCase().contains(_searchQuery) ||
            r.managerName.toLowerCase().contains(_searchQuery) ||
            r.division.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _toggleActive() async {
    if (_session == null) return;
    try {
      final newActive = !_session!.isActive;
      await SessionService.setActive(_session!.id, active: newActive);
      await _loadSession();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newActive ? 'Session is now active' : 'Session is now inactive',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _exportCSV() {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No attendance records to export'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final headers = [
      'Name',
      'Email',
      'Manager Name',
      'Division',
      'Latitude',
      'Longitude',
      'Distance (m)',
      'Timestamp',
      'Device Fingerprint',
    ];
    final rows = _records.map(
      (r) => [
        r.name,
        r.email,
        r.managerName,
        r.division,
        r.userLat,
        r.userLng,
        r.distanceMeters.toStringAsFixed(1),
        r.submittedAt.toIso8601String(),
        r.deviceFingerprint,
      ],
    );
    final csvData = const ListToCsvConverter().convert([headers, ...rows]);
    if (kIsWeb) {
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = 'attendance_${_session!.name.replaceAll(' ', '_')}.csv';
      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV export is supported on web platform'),
        ),
      );
    }
  }

  void _showQRCodeDialog() {
    if (_session == null) return;
    final baseUri = Uri.base;
    final attendeeUrl =
        '${baseUri.scheme}://${baseUri.host}${baseUri.port != 80 && baseUri.port != 443 && baseUri.port != 0 ? ':${baseUri.port}' : ''}/#/attend/${_session!.id}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.qr_code, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Attendee QR Code',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 50.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Attendees can scan this QR code or navigate to the link below to check-in.',
                style: Theme.of(
                  ctx,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: attendeeUrl,
                  version: QrVersions.auto,
                  size: 240.0,
                  gapless: false,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SelectableText(
                attendeeUrl,
                style: const TextStyle(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: attendeeUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copied to clipboard!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Link'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _loadingSession || (_session != null && _loadingRecords);
    return Scaffold(
      appBar: AppBar(
        title: Text(_session?.name ?? 'Session Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/sessions'),
        ),
        actions: [
          if (_session != null) ...[
            IconButton(
              onPressed: _showQRCodeDialog,
              icon: const Icon(Icons.qr_code),
              tooltip: 'Show QR Code',
            ),
            IconButton(
              onPressed: _exportCSV,
              icon: const Icon(Icons.download),
              tooltip: 'Export CSV',
            ),
          ],
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? _buildErrorWidget()
          : _session == null
          ? const Center(child: Text('Session not found'))
          : _buildMainContent(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 54),
          const SizedBox(height: 16),
          Text(_error!, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _loadAll, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final session = _session!;
    final timeFormat = DateFormat('yyyy-MM-dd HH:mm');
    final (statusColor, statusLabel) = switch (session.status) {
      SessionStatus.open => (AppColors.success, 'Open'),
      SessionStatus.upcoming => (AppColors.primary, 'Upcoming'),
      SessionStatus.closed => (Colors.grey, 'Closed'),
      SessionStatus.inactive => (AppColors.error, 'Inactive'),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    session.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      border: Border.all(
                                        color: statusColor.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (session.description != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  session.description!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey[300]),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _toggleActive,
                              icon: Icon(
                                session.isActive
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                              label: Text(
                                session.isActive ? 'Deactivate' : 'Activate',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: session.isActive
                                    ? AppColors.error
                                    : AppColors.success,
                                side: BorderSide(
                                  color: session.isActive
                                      ? AppColors.error.withValues(alpha: 0.5)
                                      : AppColors.success.withValues(
                                          alpha: 0.5,
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GradientButton(
                              label: 'QR Code',
                              icon: Icons.qr_code,
                              width: 120,
                              height: 38,
                              onPressed: _showQRCodeDialog,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 32, color: Colors.white24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 600;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isNarrow ? 2 : 4,
                          childAspectRatio: isNarrow ? 2.2 : 2.5,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          children: [
                            _buildInfoTile(
                              'Location Target',
                              '${session.targetLat.toStringAsFixed(5)}, ${session.targetLng.toStringAsFixed(5)}',
                              Icons.location_on,
                            ),
                            _buildInfoTile(
                              'Allowed Radius',
                              '${session.radiusMeters} meters',
                              Icons.radar,
                            ),
                            _buildInfoTile(
                              'Start Time',
                              timeFormat.format(session.startTime),
                              Icons.access_time,
                            ),
                            _buildInfoTile(
                              'End Time',
                              timeFormat.format(session.endTime),
                              Icons.timer_off_outlined,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance List',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Total of ${_records.length} submission(s)',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 250,
                    height: 40,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _exportCSV,
                    icon: const Icon(
                      Icons.download,
                      color: AppColors.secondary,
                    ),
                    tooltip: 'Export CSV',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_filteredRecords.isEmpty)
                GlassCard(
                  child: Container(
                    height: 150,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 40,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No matches found'
                              : 'No attendance recorded yet',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Colors.white.withValues(alpha: 0.05),
                        ),
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Name',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Email',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Manager',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Division',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Distance',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Submitted At',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Fingerprint',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        rows: _filteredRecords.map((r) {
                          final isTooFar =
                              r.distanceMeters > session.radiusMeters;
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  r.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              DataCell(Text(r.email)),
                              DataCell(Text(r.managerName)),
                              DataCell(Text(r.division)),
                              DataCell(
                                Row(
                                  children: [
                                    Icon(
                                      isTooFar
                                          ? Icons.warning_amber
                                          : Icons.check_circle_outline,
                                      color: isTooFar
                                          ? AppColors.error
                                          : AppColors.success,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${r.distanceMeters.toStringAsFixed(1)}m',
                                      style: TextStyle(
                                        color: isTooFar
                                            ? AppColors.error
                                            : AppColors.success,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(Text(timeFormat.format(r.submittedAt))),
                              DataCell(
                                Text(
                                  r.deviceFingerprint.substring(0, 8),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.secondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SelectableText(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
