import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'admin@boginenigroup.com');
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (ok && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOuter,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spaceLG),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Logo / Brand ─────────────────────────────────────
                const _BrandHeader(),
                const SizedBox(height: AppDimensions.spaceXXL),

                // ── Card ─────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  ),
                  padding: const EdgeInsets.all(AppDimensions.spaceXL),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Sign in',
                          style: TextStyle(
                            fontSize: AppDimensions.fontH2,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spaceXS),
                        const Text(
                          'Access the Bogineni Group property platform.',
                          style: TextStyle(
                            fontSize: AppDimensions.fontBase,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spaceXL),

                        // Email
                        _InputLabel('Email'),
                        const SizedBox(height: AppDimensions.spaceXS),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          style: const TextStyle(
                            fontSize: AppDimensions.fontBase,
                            color: AppColors.textPrimary,
                          ),
                          decoration: _inputDecoration('admin@boginenigroup.com'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Email required';
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.spaceMD),

                        // Password
                        _InputLabel('Password'),
                        const SizedBox(height: AppDimensions.spaceXS),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          style: const TextStyle(
                            fontSize: AppDimensions.fontBase,
                            color: AppColors.textPrimary,
                          ),
                          decoration: _inputDecoration('••••••••••').copyWith(
                            suffixIcon: GestureDetector(
                              onTap: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              child: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: AppDimensions.iconMD,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          onFieldSubmitted: (_) => _submit(),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password required';
                            if (v.length < 6) return 'Password too short';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.spaceLG),

                        // Error message
                        Consumer<AuthProvider>(
                          builder: (_, auth, __) {
                            if (auth.errorMessage == null) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppDimensions.spaceMD),
                              child: Container(
                                padding: const EdgeInsets.all(AppDimensions.spaceMD),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E0A0A),
                                  borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusXS),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: AppColors.error,
                                        size: AppDimensions.iconMD),
                                    const SizedBox(width: AppDimensions.spaceSM),
                                    Expanded(
                                      child: Text(
                                        auth.errorMessage!,
                                        style: const TextStyle(
                                          color: AppColors.error,
                                          fontSize: AppDimensions.fontBase,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Login button
                        Consumer<AuthProvider>(
                          builder: (_, auth, __) {
                            final isLoading = auth.status == AuthStatus.loading;
                            return SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentSilver,
                                  foregroundColor: AppColors.bgOuter,
                                  elevation: 0,
                                  shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.zero),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.bgOuter,
                                        ),
                                      )
                                    : const Text(
                                        'SIGN IN',
                                        style: TextStyle(
                                          fontSize: AppDimensions.fontBase,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.spaceLG),
                const Center(
                  child: Text(
                    '© 2025 Bogineni Group. All rights reserved.',
                    style: TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          color: AppColors.textMuted, fontSize: AppDimensions.fontBase),
      filled: true,
      fillColor: AppColors.pageBg,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceMD, vertical: AppDimensions.spaceMD),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.accentSilver),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.error),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.error),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wordmark
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentGold,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
              ),
              child: const Icon(Icons.domain,
                  color: AppColors.bgOuter, size: AppDimensions.iconLG),
            ),
            const SizedBox(width: AppDimensions.spaceSM),
            const Text(
              'BOGINENI GROUP',
              style: TextStyle(
                fontSize: AppDimensions.fontH3,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceSM),
        const Text(
          'Property Management Platform',
          style: TextStyle(
            fontSize: AppDimensions.fontBase,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _InputLabel extends StatelessWidget {
  const _InputLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: AppDimensions.fontSM,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}
