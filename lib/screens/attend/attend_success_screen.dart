import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme.dart';
import '../../widgets/glass_card.dart';

class AttendSuccessScreen extends StatefulWidget {
  final String sessionId;
  final String attendeeName;
  final String sessionName;

  const AttendSuccessScreen({
    super.key,
    required this.sessionId,
    required this.attendeeName,
    required this.sessionName,
  });

  @override
  State<AttendSuccessScreen> createState() => _AttendSuccessScreenState();
}

class _AttendSuccessScreenState extends State<AttendSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submittedAt = DateFormat(
      'EEEE, MMM dd yyyy • HH:mm',
    ).format(DateTime.now());

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated check icon
                  ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: AppGradients.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.4),
                            blurRadius: 32,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Attendance Recorded!',
                    style: Theme.of(
                      context,
                    ).textTheme.displayLarge?.copyWith(fontSize: 28),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your attendance has been successfully submitted.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  GlassCard(
                    child: Column(
                      children: [
                        _summaryRow(
                          context,
                          icon: Icons.person,
                          label: 'Name',
                          value: widget.attendeeName,
                        ),
                        const Divider(height: 24),
                        _summaryRow(
                          context,
                          icon: Icons.event,
                          label: 'Session',
                          value: widget.sessionName.isEmpty
                              ? 'Attendance Session'
                              : widget.sessionName,
                        ),
                        const Divider(height: 24),
                        _summaryRow(
                          context,
                          icon: Icons.access_time,
                          label: 'Submitted At',
                          value: submittedAt,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.success,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You can safely close this page. Your attendance has been saved.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}
