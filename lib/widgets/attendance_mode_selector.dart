import 'package:flutter/material.dart';
import '../models/session.dart';
import '../theme.dart';

/// A segmented chip selector for choosing the attendance mode.
/// Shows three chips: Offline, Hybrid, Online.
class AttendanceModeSelector extends StatelessWidget {
  final AttendanceMode selected;
  final ValueChanged<AttendanceMode> onChanged;

  const AttendanceModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.wifi_tethering,
              color: AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Attendance Mode',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _ModeChip(
              mode: AttendanceMode.offline,
              selected: selected,
              icon: Icons.location_on,
              label: 'Offline',
              color: AppColors.error,
              onTap: onChanged,
            ),
            const SizedBox(width: 10),
            _ModeChip(
              mode: AttendanceMode.hybrid,
              selected: selected,
              icon: Icons.swap_horiz,
              label: 'Hybrid',
              color: AppColors.warning,
              onTap: onChanged,
            ),
            const SizedBox(width: 10),
            _ModeChip(
              mode: AttendanceMode.online,
              selected: selected,
              icon: Icons.language,
              label: 'Online',
              color: AppColors.success,
              onTap: onChanged,
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildDescription(context),
      ],
    );
  }

  Widget _buildDescription(BuildContext context) {
    final (description, color) = switch (selected) {
      AttendanceMode.offline => (
          'Location check required — attendee must be within the geofence.',
          AppColors.error,
        ),
      AttendanceMode.hybrid => (
          'Location is tracked but not required to submit attendance.',
          AppColors.warning,
        ),
      AttendanceMode.online => (
          'No location check — anyone with the link can attend remotely.',
          AppColors.success,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final AttendanceMode mode;
  final AttendanceMode selected;
  final IconData icon;
  final String label;
  final Color color;
  final ValueChanged<AttendanceMode> onTap;

  const _ModeChip({
    required this.mode,
    required this.selected,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = mode == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(
              color: isSelected ? color : AppColors.cardBorder,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? color : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
