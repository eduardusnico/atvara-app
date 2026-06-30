import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/attendance_record.dart';
import '../../models/session.dart';
import '../../services/attendance_service.dart';
import '../../services/company_service.dart';
import '../../services/fingerprint_service.dart';
import '../../services/location_service.dart';
import '../../services/session_service.dart';
import '../../theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';

// ── Enums for screen states ──────────────────────────────────────────────────

enum _SessionState { loading, notFound, inactive, upcoming, closed, open }

enum _LocationState {
  idle,
  detecting,
  inRange,
  outOfRange,
  permissionDenied,
  error,
}

enum _SubmitState { idle, submitting, duplicateEmail, duplicateDevice, error }

// ── Main Screen ──────────────────────────────────────────────────────────────

class AttendFormScreen extends StatefulWidget {
  final String sessionId;

  const AttendFormScreen({super.key, required this.sessionId});

  @override
  State<AttendFormScreen> createState() => _AttendFormScreenState();
}

class _AttendFormScreenState extends State<AttendFormScreen> {
  // Session
  _SessionState _sessionState = _SessionState.loading;
  Session? _session;

  // Location
  _LocationState _locationState = _LocationState.idle;
  Position? _userPosition;
  double? _distanceMeters;
  String? _locationError;

  // Form
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _managerCtrl = TextEditingController();
  final _divisionCtrl = TextEditingController();

  // Company dropdown
  List<String> _companies = [];
  String? _selectedCompany;
  bool _loadingCompanies = true;

  // Role selection
  String? _selectedRole; // 'Trainer' or 'Participant'

  // Submit
  _SubmitState _submitState = _SubmitState.idle;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _loadCompanies();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _managerCtrl.dispose();
    _divisionCtrl.dispose();
    super.dispose();
  }

  // ── Data Loading ─────────────────────────────────────────────────────────

  Future<void> _loadSession() async {
    setState(() => _sessionState = _SessionState.loading);
    try {
      final session = await SessionService.getSession(widget.sessionId);
      if (!mounted) return;
      if (session == null) {
        setState(() => _sessionState = _SessionState.notFound);
        return;
      }
      final status = session.status;
      setState(() {
        _session = session;
        _sessionState = switch (status) {
          SessionStatus.open => _SessionState.open,
          SessionStatus.upcoming => _SessionState.upcoming,
          SessionStatus.closed => _SessionState.closed,
          SessionStatus.inactive => _SessionState.inactive,
        };
      });
    } catch (_) {
      if (mounted) setState(() => _sessionState = _SessionState.notFound);
    }
  }

  Future<void> _loadCompanies() async {
    try {
      final list = await CompanyService.getCompanies();
      if (mounted) {
        setState(() {
          _companies = list;
          _loadingCompanies = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _companies = kDefaultCompanies;
          _loadingCompanies = false;
        });
      }
    }
  }

  // ── Location Detection ───────────────────────────────────────────────────

  Future<void> _detectLocation() async {
    setState(() {
      _locationState = _LocationState.detecting;
      _locationError = null;
      _distanceMeters = null;
    });

    final result = await LocationService.getCurrentPosition();

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _locationError = result.error;
        _locationState = _LocationState.error;
      });
      return;
    }

    final position = result.position!;
    final distance = LocationService.distanceBetween(
      fromLat: position.latitude,
      fromLng: position.longitude,
      toLat: _session!.targetLat,
      toLng: _session!.targetLng,
    );

    setState(() {
      _userPosition = position;
      _distanceMeters = distance;
      _locationState = distance <= _session!.radiusMeters
          ? _LocationState.inRange
          : _LocationState.outOfRange;
    });
  }

  // ── Submit Attendance ────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_locationState != _LocationState.inRange) return;
    if (_selectedCompany == null || _selectedRole == null) return;

    setState(() => _submitState = _SubmitState.submitting);

    final fingerprint = await FingerprintService.getFingerprint();

    final record = AttendanceRecord(
      id: '',
      sessionId: widget.sessionId,
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim().toLowerCase(),
      managerName: _managerCtrl.text.trim(),
      division: _divisionCtrl.text.trim(),
      company: _selectedCompany!,
      role: _selectedRole!,
      submittedAt: DateTime.now(),
      userLat: _userPosition!.latitude,
      userLng: _userPosition!.longitude,
      distanceMeters: _distanceMeters!,
      deviceFingerprint: fingerprint,
    );

    final error = await AttendanceService.submit(record);

    if (!mounted) return;

    if (error == null) {
      context.go(
        '/attend/${widget.sessionId}/success'
        '?name=${Uri.encodeComponent(_nameCtrl.text.trim())}'
        '&session=${Uri.encodeComponent(_session!.name)}',
      );
      return;
    }

    setState(() {
      _submitState = switch (error) {
        AttendanceError.emailAlreadySubmitted => _SubmitState.duplicateEmail,
        AttendanceError.deviceAlreadySubmitted => _SubmitState.duplicateDevice,
        AttendanceError.unknown => _SubmitState.error,
      };
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_sessionState) {
        _SessionState.loading => _buildLoading(),
        _SessionState.notFound => _buildStatus(
          icon: Icons.link_off,
          title: 'Session Not Found',
          message:
              'This attendance link is invalid or has been removed. Please check your link and try again.',
          iconColor: AppColors.error,
        ),
        _SessionState.inactive => _buildStatus(
          icon: Icons.pause_circle_outline,
          title: 'Session Inactive',
          message:
              'This attendance session is currently inactive. Please contact your organizer.',
          iconColor: AppColors.warning,
        ),
        _SessionState.upcoming => _buildStatus(
          icon: Icons.schedule,
          title: 'Not Started Yet',
          message:
              'This attendance session opens at ${DateFormat('MMM dd, yyyy • HH:mm').format(_session!.startTime)}.',
          iconColor: AppColors.primary,
        ),
        _SessionState.closed => _buildStatus(
          icon: Icons.lock_clock,
          title: 'Session Closed',
          message:
              'The attendance window closed at ${DateFormat('HH:mm, MMM dd').format(_session!.endTime)}.',
          iconColor: AppColors.textSecondary,
        ),
        _SessionState.open => _buildForm(),
      },
    );
  }

  // ── Loading ──────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Loading session…',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ── Status / Error Screens ───────────────────────────────────────────────

  Widget _buildStatus({
    required IconData icon,
    required String title,
    required String message,
    required Color iconColor,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBrand(context),
              const SizedBox(height: 32),
              GlassCard(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Main Form ────────────────────────────────────────────────────────────

  Widget _buildForm() {
    final canSubmit =
        _locationState == _LocationState.inRange &&
        _submitState != _SubmitState.submitting;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              _buildBrand(context),
              const SizedBox(height: 28),

              // Session header card
              _buildSessionHeader(),
              const SizedBox(height: 16),

              // Location card
              _buildLocationCard(),
              const SizedBox(height: 16),

              // Form card
              GlassCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.edit_note,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Your Information',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildField(
                        controller: _nameCtrl,
                        label: 'Full Name',
                        hint: 'Enter your full name',
                        icon: Icons.person_outline,
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Full name is required'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _emailCtrl,
                        label: 'Email Address',
                        hint: 'Enter your email address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v?.trim().isEmpty ?? true) {
                            return 'Email is required';
                          }
                          if (!RegExp(
                            r'^[\w\-.]+@[\w\-]+\.\w+$',
                          ).hasMatch(v!.trim())) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _managerCtrl,
                        label: 'Direct Manager Name',
                        hint: "Enter your manager's name",
                        icon: Icons.supervisor_account_outlined,
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Manager name is required'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _divisionCtrl,
                        label: 'Division / Department',
                        hint: 'e.g. Engineering, Marketing',
                        icon: Icons.business_outlined,
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Division is required'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // ── Company Dropdown ──────────────────────────────
                      _loadingCompanies
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary),
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedCompany,
                              isExpanded: true,
                              decoration: AppTheme.inputDecoration(
                                label: 'Company',
                                hint: 'Select your company',
                                prefixIcon: Icons.corporate_fare,
                              ),
                              dropdownColor: AppColors.surface,
                              items: _companies.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedCompany = v),
                              validator: (v) =>
                                  v == null ? 'Please select your company' : null,
                            ),
                      const SizedBox(height: 14),

                      // ── Role Selection ────────────────────────────────
                      _buildRoleSelector(),
                      const SizedBox(height: 24),

                      // Error feedback
                      if (_submitState == _SubmitState.duplicateEmail)
                        _buildErrorBanner(
                          'This email has already submitted attendance for this session.',
                        ),
                      if (_submitState == _SubmitState.duplicateDevice)
                        _buildErrorBanner(
                          'Attendance from this device has already been recorded.',
                        ),
                      if (_submitState == _SubmitState.error)
                        _buildErrorBanner(
                          'Submission failed. Please try again.',
                        ),

                      GradientButton(
                        label: 'Submit Attendance',
                        icon: Icons.check_circle_outline,
                        onPressed: canSubmit ? _submit : null,
                        isLoading: _submitState == _SubmitState.submitting,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-Widgets ──────────────────────────────────────────────────────────

  Widget _buildRoleSelector() {
    return FormField<String>(
      initialValue: _selectedRole,
      validator: (v) => (v == null || v.isEmpty) ? 'Please select your role' : null,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_outlined,
                    color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Participation Role',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _roleChip('Participant', Icons.people_outline)),
                const SizedBox(width: 12),
                Expanded(child: _roleChip('Trainer', Icons.school_outlined)),
              ],
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _roleChip(String role, IconData icon) {
    final selected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 18),
            const SizedBox(width: 8),
            Text(
              role,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrand(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.fingerprint, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        Text(
          'Atvara',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildSessionHeader() {
    final s = _session!;
    final fmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('EEE, MMM dd yyyy');

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.event_available,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (s.description != null && s.description!.isNotEmpty)
                  Text(
                    s.description!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${dateFmt.format(s.startTime)} • ${fmt.format(s.startTime)} – ${fmt.format(s.endTime)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'OPEN',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Location Verification',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'You must be within ${_session!.radiusMeters}m of the event location.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _buildLocationStatus(),
          const SizedBox(height: 12),
          if (_locationState == _LocationState.idle ||
              _locationState == _LocationState.error ||
              _locationState == _LocationState.outOfRange ||
              _locationState == _LocationState.permissionDenied)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _detectLocation,
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(
                  _locationState == _LocationState.idle
                      ? 'Detect My Location'
                      : 'Try Again',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationStatus() {
    return switch (_locationState) {
      _LocationState.idle => _locationChip(
        icon: Icons.location_searching,
        color: AppColors.textSecondary,
        label: 'Location not yet detected',
      ),
      _LocationState.detecting => Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Detecting your location…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      _LocationState.inRange => _locationChip(
        icon: Icons.check_circle,
        color: AppColors.success,
        label:
            '✓ In range — ${_distanceMeters!.toStringAsFixed(0)}m from venue',
        bgColor: AppColors.successBg,
        borderColor: AppColors.success.withValues(alpha: 0.3),
      ),
      _LocationState.outOfRange => _locationChip(
        icon: Icons.cancel,
        color: AppColors.error,
        label:
            '${_distanceMeters!.toStringAsFixed(0)}m away — must be within ${_session!.radiusMeters}m',
        bgColor: AppColors.errorBg,
        borderColor: AppColors.error.withValues(alpha: 0.3),
      ),
      _LocationState.permissionDenied || _LocationState.error => _locationChip(
        icon: Icons.warning_amber,
        color: AppColors.warning,
        label: _locationError ?? 'Location error',
        bgColor: AppColors.warningBg,
        borderColor: AppColors.warning.withValues(alpha: 0.3),
      ),
    };
  }

  Widget _locationChip({
    required IconData icon,
    required Color color,
    required String label,
    Color? bgColor,
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor ?? AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: AppTheme.inputDecoration(
        label: label,
        hint: hint,
        prefixIcon: icon,
      ),
      validator: validator,
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
