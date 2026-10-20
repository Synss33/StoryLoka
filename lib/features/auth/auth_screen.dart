import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/storyloka_card.dart';
import 'auth_controller.dart';
import 'auth_store.dart';

/// SCR-01 — Splash, Register, Login & Biometrik (F-01–F-03).
///
/// Satu layar berisi tab **Masuk / Daftar** sesuai wireframe dokumen desain
/// Bagian 5 (SCR-01). [startMessage] dipakai splash untuk memberi tahu
/// layar ini: `'expired'` → dialog sesi berakhir (TC-05), `'biometric'` →
/// biometrik gagal 3× (TC-07).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.startMessage});

  final String? startMessage;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthMode { login, register }

/// Build flag: tombol "Masuk Demo" hanya tampil pada build demo
/// (`--dart-define=DEMO_MODE=true`) — build biasa tidak memakainya.
const bool _demoModeEnabled = bool.fromEnvironment('DEMO_MODE');

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController(); // login
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController(); // register
  final _emailCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  /// Tombol biometrik hanya tampil bila pengaturan aktif, perangkat
  /// mendukung, dan sesi tersimpan (dokumen desain SCR-01).
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final session = await ref.read(authStoreProvider).readSession();
    var available = false;
    if (session != null) {
      available = await ref
          .read(authControllerProvider.notifier)
          .shouldUseBiometric(session.userId);
    }
    if (!mounted) return;
    setState(() => _biometricAvailable = available);

    if (widget.startMessage == 'expired') _showExpiredDialog();
    if (widget.startMessage == 'biometric') {
      ref
          .read(authControllerProvider.notifier)
          .copyWithMessage('Biometrik gagal 3 kali. Gunakan password.');
      setState(() {});
    }
  }

  void _showExpiredDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sesi berakhir'),
        content: const Text('Sesi berakhir, silakan masuk lagi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Oke'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(authControllerProvider.notifier);
    final String? error;
    if (_mode == _AuthMode.login) {
      error = await controller.login(
        identifier: _identifierCtrl.text,
        password: _passwordCtrl.text,
      );
    } else {
      error = await controller.register(
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        confirm: _confirmCtrl.text,
      );
    }
    if (error == null && mounted) context.go('/');
  }

  /// Masuk sebagai akun demo berisi data contoh (build DEMO_MODE saja).
  Future<void> _loginDemo() async {
    final error = await ref.read(authControllerProvider.notifier).loginDemo();
    if (error == null && mounted) context.go('/');
  }

  Future<void> _biometricLogin() async {
    final controller = ref.read(authControllerProvider.notifier);
    final session = await ref.read(authStoreProvider).readSession();
    if (session == null) return;

    final ok = await controller.promptBiometric();
    if (!mounted) return;
    if (ok) {
      controller.resetBiometricFailures();
      controller.adoptSession(session.userId);
      context.go('/');
    } else {
      controller.noteBiometricFailure();
      setState(() {}); // perbarui hitungan percobaan (TC-07)
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LogoHeader(p: p),
                  const SizedBox(height: AppSpacing.cardGap),
                  _AuthCard(
                    mode: _mode,
                    onModeChanged: (mode) => setState(() => _mode = mode),
                    formKey: _formKey,
                    identifierCtrl: _identifierCtrl,
                    passwordCtrl: _passwordCtrl,
                    nameCtrl: _nameCtrl,
                    emailCtrl: _emailCtrl,
                    confirmCtrl: _confirmCtrl,
                    obscurePassword: _obscurePassword,
                    obscureConfirm: _obscureConfirm,
                    onTogglePassword: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onToggleConfirm: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    auth: auth,
                    onSubmit: _submit,
                    onBiometric: _biometricAvailable ? _biometricLogin : null,
                  ),
                  if (_demoModeEnabled) ...[
                    const SizedBox(height: AppSpacing.cardGap),
                    SecondaryButton(
                      key: const Key('auth-demo'),
                      label: 'Masuk Demo (data contoh)',
                      icon: Icons.auto_awesome,
                      loading: auth.busy,
                      onPressed: _loginDemo,
                    ),
                    const SizedBox(height: AppSpacing.micro),
                    Text(
                      'Akun demo@storyloka.app — data hanya contoh, aman dihapus '
                      'lewat logout/hapus aplikasi.',
                      style: AppTypography.caption.copyWith(color: p.neutral500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader({required this.p});

  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: p.primary500,
            borderRadius: AppRadius.largeAll,
          ),
          child: Icon(Icons.menu_book, color: p.onPrimary, size: 44),
        ),
        const SizedBox(height: AppSpacing.screenMargin),
        Text(
          'Storyloka',
          style: AppTypography.h1.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: AppSpacing.micro),
        Text(
          'Temukan, Simpan, & Lacak Bacaanmu',
          style: AppTypography.body2.copyWith(color: p.neutral500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Kartu form SCR-01 (tab Masuk/Daftar + field + tombol).
class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.mode,
    required this.onModeChanged,
    required this.formKey,
    required this.identifierCtrl,
    required this.passwordCtrl,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.confirmCtrl,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.auth,
    required this.onSubmit,
    required this.onBiometric,
  });

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onModeChanged;
  final GlobalKey<FormState> formKey;
  final TextEditingController identifierCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController confirmCtrl;
  final bool obscurePassword;
  final bool obscureConfirm;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final AuthState auth;
  final VoidCallback onSubmit;

  /// `null` → tombol biometrik disembunyikan (perangkat tanpa biometrik).
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final isLogin = mode == _AuthMode.login;

    return StorylokaCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ModeTabs(mode: mode, onChanged: onModeChanged),
            const SizedBox(height: AppSpacing.screenMargin),
            if (isLogin) ...[
              TextFormField(
                key: const Key('field-login-identifier'),
                controller: identifierCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email / Username',
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              _PasswordField(
                fieldKey: const Key('field-login-password'),
                controller: passwordCtrl,
                label: 'Password',
                obscure: obscurePassword,
                onToggle: onTogglePassword,
                onFieldSubmitted: (_) => onSubmit(),
              ),
            ] else ...[
              TextFormField(
                key: const Key('field-register-name'),
                controller: nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nama lengkap'),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              TextFormField(
                key: const Key('field-register-email'),
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              _PasswordField(
                fieldKey: const Key('field-register-password'),
                controller: passwordCtrl,
                label: 'Password (min. 8 karakter)',
                obscure: obscurePassword,
                onToggle: onTogglePassword,
              ),
              const SizedBox(height: AppSpacing.micro),
              _PasswordStrength(controller: passwordCtrl),
              const SizedBox(height: AppSpacing.cardGap),
              _PasswordField(
                fieldKey: const Key('field-register-confirm'),
                controller: confirmCtrl,
                label: 'Konfirmasi password',
                obscure: obscureConfirm,
                onToggle: onToggleConfirm,
                onFieldSubmitted: (_) => onSubmit(),
              ),
            ],
            if (auth.error != null) ...[
              const SizedBox(height: AppSpacing.cardGap),
              Text(
                auth.error!,
                key: const Key('auth-error'),
                style: AppTypography.body2.copyWith(color: p.danger500),
                textAlign: TextAlign.center,
              ),
            ],
            if (auth.failedAttempts > 0) ...[
              const SizedBox(height: AppSpacing.micro),
              Text(
                'Percobaan gagal: ${auth.failedAttempts}',
                key: const Key('auth-attempts'),
                style: AppTypography.caption.copyWith(color: p.neutral500),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.screenMargin),
            PrimaryButton(
              key: const Key('auth-submit'),
              label: isLogin ? 'MASUK' : 'DAFTAR',
              loading: auth.busy,
              onPressed: onSubmit,
            ),
            if (onBiometric != null) ...[
              const SizedBox(height: AppSpacing.cardGap),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.cardGap,
                    ),
                    child: Text(
                      'atau',
                      style:
                          AppTypography.caption.copyWith(color: p.neutral500),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.cardGap),
              SecondaryButton(
                key: const Key('auth-biometric'),
                label: 'Masuk dengan Biometrik',
                icon: Icons.fingerprint,
                onPressed: onBiometric,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.mode, required this.onChanged});

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.micro),
      decoration: BoxDecoration(
        color: p.brightness == Brightness.dark ? p.bg : p.neutral100,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        children: [
          _TabItem(
            label: 'Masuk',
            active: mode == _AuthMode.login,
            onTap: () => onChanged(_AuthMode.login),
          ),
          _TabItem(
            label: 'Daftar',
            active: mode == _AuthMode.register,
            onTap: () => onChanged(_AuthMode.register),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Expanded(
      child: InkWell(
        key: Key('tab-$label'),
        borderRadius: AppRadius.pillAll,
        onTap: onTap,
        child: Container(
          height: AppSpacing.touchTarget - AppSpacing.micro * 2,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? p.primary500 : Colors.transparent,
            borderRadius: AppRadius.pillAll,
          ),
          child: Text(
            label,
            style: AppTypography.body1.copyWith(
              color: active ? p.onPrimary : p.textPrimary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.onFieldSubmitted,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      obscureText: widget.obscure,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          key: Key('toggle-${widget.fieldKey}'),
          icon: Icon(widget.obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: widget.onToggle,
        ),
      ),
    );
  }
}

/// Indikator kekuatan password (dokumen desain SCR-01: "indikator kekuatan").
/// Memantau [controller] agar bar diperbarui saat pengguna mengetik.
class _PasswordStrength extends StatefulWidget {
  const _PasswordStrength({required this.controller});

  final TextEditingController controller;

  @override
  State<_PasswordStrength> createState() => _PasswordStrengthState();
}

class _PasswordStrengthState extends State<_PasswordStrength> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  int _scoreOf(String password) {
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      score++;
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final password = widget.controller.text;
    if (password.isEmpty) return const SizedBox.shrink();

    final score = _scoreOf(password);
    final (label, color) = switch (score) {
      0 || 1 => ('Lemah', p.danger500),
      2 || 3 => ('Sedang', p.warning500),
      _ => ('Kuat', p.success500),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadius.pillAll,
          child: LinearProgressIndicator(
            key: const Key('password-strength-bar'),
            value: score / 4,
            minHeight: 4,
            color: color,
            backgroundColor: p.neutral100,
          ),
        ),
        const SizedBox(height: AppSpacing.micro),
        Text(
          'Kekuatan: $label',
          key: const Key('password-strength-label'),
          style: AppTypography.caption.copyWith(color: color),
        ),
      ],
    );
  }
}
