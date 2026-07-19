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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOuter,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spaceLG),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BrandHeader(),
                const SizedBox(height: AppDimensions.spaceXXL),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tab bar
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: TabBar(
                          controller: _tabs,
                          indicatorColor: AppColors.accentSilver,
                          labelColor: AppColors.textPrimary,
                          unselectedLabelColor: AppColors.textMuted,
                          labelStyle: const TextStyle(
                            fontSize: AppDimensions.fontBase,
                            fontWeight: FontWeight.w600,
                          ),
                          tabs: const [
                            Tab(text: 'Sign In'),
                            Tab(text: 'Register'),
                          ],
                        ),
                      ),

                      // Tab views
                      SizedBox(
                        height: _tabs.index == 0 ? 340 : 480,
                        child: TabBarView(
                          controller: _tabs,
                          children: const [
                            _SignInForm(),
                            _RegisterForm(),
                          ],
                        ),
                      ),
                    ],
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
}

// ── Sign In Form ─────────────────────────────────────────────────────

class _SignInForm extends StatefulWidget {
  const _SignInForm();

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'admin@boginenigroup.com');
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.signIn(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      context.go(auth.isTenant ? '/tenant' : '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spaceXL),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InputLabel('Email'),
            const SizedBox(height: AppDimensions.spaceXS),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(
                  fontSize: AppDimensions.fontBase,
                  color: AppColors.textPrimary),
              decoration: _inputDecoration('you@example.com'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.spaceMD),
            _InputLabel('Password'),
            const SizedBox(height: AppDimensions.spaceXS),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              style: const TextStyle(
                  fontSize: AppDimensions.fontBase,
                  color: AppColors.textPrimary),
              decoration: _inputDecoration('••••••••').copyWith(
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure
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
                if (v.length < 6) return 'Too short';
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.spaceLG),
            Consumer<AuthProvider>(
              builder: (_, auth, __) {
                if (auth.errorMessage != null) {
                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppDimensions.spaceMD),
                    child: _ErrorBanner(auth.errorMessage!),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Consumer<AuthProvider>(
              builder: (_, auth, __) {
                final loading = auth.status == AuthStatus.loading;
                return _PrimaryButton(
                  label: 'SIGN IN',
                  loading: loading,
                  onPressed: _submit,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Register Form ────────────────────────────────────────────────────

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  String _role = 'tenant';

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      firstName: _firstCtrl.text.trim(),
      lastName: _lastCtrl.text.trim(),
      role: _role,
    );
    if (!mounted) return;
    if (ok) {
      context.go(_role == 'tenant' ? '/tenant' : '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceXL),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InputLabel('First Name'),
                      const SizedBox(height: AppDimensions.spaceXS),
                      TextFormField(
                        controller: _firstCtrl,
                        style: const TextStyle(
                            fontSize: AppDimensions.fontBase,
                            color: AppColors.textPrimary),
                        decoration: _inputDecoration('First'),
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InputLabel('Last Name'),
                      const SizedBox(height: AppDimensions.spaceXS),
                      TextFormField(
                        controller: _lastCtrl,
                        style: const TextStyle(
                            fontSize: AppDimensions.fontBase,
                            color: AppColors.textPrimary),
                        decoration: _inputDecoration('Last'),
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceMD),
            _InputLabel('Email'),
            const SizedBox(height: AppDimensions.spaceXS),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(
                  fontSize: AppDimensions.fontBase,
                  color: AppColors.textPrimary),
              decoration: _inputDecoration('you@example.com'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.spaceMD),
            _InputLabel('Password'),
            const SizedBox(height: AppDimensions.spaceXS),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              style: const TextStyle(
                  fontSize: AppDimensions.fontBase,
                  color: AppColors.textPrimary),
              decoration: _inputDecoration('Min. 6 characters').copyWith(
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: AppDimensions.iconMD,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password required';
                if (v.length < 6) return 'Min. 6 characters';
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.spaceMD),
            _InputLabel('I am a'),
            const SizedBox(height: AppDimensions.spaceXS),
            Row(
              children: [
                _RoleChip(
                  label: 'Tenant',
                  selected: _role == 'tenant',
                  onTap: () => setState(() => _role = 'tenant'),
                ),
                const SizedBox(width: AppDimensions.spaceSM),
                _RoleChip(
                  label: 'Admin',
                  selected: _role == 'admin',
                  onTap: () => setState(() => _role = 'admin'),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceLG),
            Consumer<AuthProvider>(
              builder: (_, auth, __) {
                if (auth.errorMessage != null) {
                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppDimensions.spaceMD),
                    child: _ErrorBanner(auth.errorMessage!),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Consumer<AuthProvider>(
              builder: (_, auth, __) {
                final loading = auth.status == AuthStatus.loading;
                return _PrimaryButton(
                  label: 'CREATE ACCOUNT',
                  loading: loading,
                  onPressed: _submit,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  const _RoleChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceMD,
          vertical: AppDimensions.spaceSM,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSilver : AppColors.pageBg,
          border: Border.all(
            color: selected ? AppColors.accentSilver : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppDimensions.fontBase,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.bgOuter : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(
      {required this.label, required this.loading, required this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentSilver,
          foregroundColor: AppColors.bgOuter,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.bgOuter),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: AppDimensions.fontBase,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: const Color(0xFF2E0A0A),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.error, size: AppDimensions.iconMD),
          const SizedBox(width: AppDimensions.spaceSM),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: AppColors.error, fontSize: AppDimensions.fontBase),
            ),
          ),
        ],
      ),
    );
  }
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
