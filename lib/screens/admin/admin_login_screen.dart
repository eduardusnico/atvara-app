import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config.dart';
import '../../router.dart';
import '../../theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _hasError = false;
  bool _loading = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _hasError = false;
      _loading = true;
    });

    // Small delay for UX
    await Future.delayed(const Duration(milliseconds: 400));

    if (_passwordCtrl.text == adminPassword) {
      adminAuthNotifier.value = true;
      if (mounted) context.go('/admin/sessions');
    } else {
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(100),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Admin Dashboard',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to manage attendance sessions',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 40),

                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Password',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        style: const TextStyle(color: AppColors.textPrimary),
                        onFieldSubmitted: (_) => _login(),
                        decoration: AppTheme.inputDecoration(
                          label: 'Admin Password',
                          hint: 'Enter password',
                          prefixIcon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      if (_hasError) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.error.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Incorrect password. Try again.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      GradientButton(
                        label: 'Sign In',
                        icon: Icons.login,
                        onPressed: _login,
                        isLoading: _loading,
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
