import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/glass_card.dart';

class AttendLandingScreen extends StatelessWidget {
  const AttendLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / brand
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(100),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Atvara',
                  style: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(fontSize: 36),
                ),
                const SizedBox(height: 8),
                Text(
                  'Smart Attendance System',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 48),
                GlassCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.primary,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Session Found',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please scan the QR code or use the attendance link provided by your event organizer.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withAlpha(30),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'The attendance link looks like:\n/attend/your-session-id',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AppColors.primary,
                                        fontFamily: 'monospace'),
                              ),
                            ),
                          ],
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
    );
  }
}
