import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';
import 'business_register_page.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  final bool _obscurePass = true;
  final bool _obscureConfirm = true;
  String _selectedRole = 'Customer';
  String? _message;

  String get _successMessage {
    return _selectedRole == 'Hairdresser'
        ? 'Kuaför kaydı başarılı.'
        : 'Kayıt başarılı.';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (fullName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        _message = 'Lütfen tüm alanları doldurun.';
      });
      return;
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _message = 'Lütfen geçerli bir e-posta adresi girin.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _message = 'Şifre en az 6 karakter olmalıdır.';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _message = 'Şifreler birbiriyle eşleşmiyor.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final success = await _authService.register(
      fullName: fullName,
      email: email,
      password: password,
      role: _selectedRole,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_successMessage)));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } else {
      setState(() {
        _message = _authService.lastAuthError ?? 'Kayıt başarısız.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const TopVisual(
            headline: 'Aramıza\nkatılın',
            subtitle: 'Ücretsiz hesabınızı dakikada oluşturun',
            tag: 'ÜCRETSİZ',
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentBar(
                      selected: 1,
                      onTap: (i) {
                        if (i == 0) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    const FieldLabel(text: 'Hesap türü'),
                    const SizedBox(height: 8),
                    _AccountTypeSelector(
                      selectedRole: _selectedRole,
                      onChanged: (role) {
                        setState(() {
                          _selectedRole = role;
                          _message = null;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    const FieldLabel(text: 'Ad Soyad'),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _nameController,
                      hint: 'Adınız Soyadınız',
                      textInputAction: TextInputAction.next,
                      prefix: const Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 13),
                    const FieldLabel(text: 'E-posta'),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _emailController,
                      hint: 'ornek@email.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefix: const Icon(
                        Icons.mail_outline_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 13),
                    const FieldLabel(text: 'Şifre'),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _passwordController,
                      hint: 'En az 6 karakter',
                      obscureText: _obscurePass,
                      textInputAction: TextInputAction.next,
                      prefix: const Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 13),
                    const FieldLabel(text: 'Şifre Tekrar'),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _confirmPasswordController,
                      hint: 'Şifrenizi tekrar girin',
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _register(),
                      prefix: const Icon(
                        Icons.lock_reset_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_message != null) ...[
                      ErrorBanner(message: _message!),
                      const SizedBox(height: 14),
                    ],
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                            strokeWidth: 2,
                          ),
                        )
                        : PrimaryButton(
                          label: 'Hesap oluştur',
                          onTap: _register,
                        ),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BusinessRegisterPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Salon sahibi misiniz? İşletme başvurusu yapın',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTypeSelector extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onChanged;

  const _AccountTypeSelector({
    required this.selectedRole,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AccountTypeTile(
            title: 'Müşteri',
            subtitle: 'Randevu al',
            icon: Icons.event_available_rounded,
            selected: selectedRole == 'Customer',
            onTap: () => onChanged('Customer'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AccountTypeTile(
            title: 'Kuaför',
            subtitle: 'Salona katıl',
            icon: Icons.content_cut_rounded,
            selected: selectedRole == 'Hairdresser',
            onTap: () => onChanged('Hairdresser'),
          ),
        ),
      ],
    );
  }
}

class _AccountTypeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AccountTypeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.accent : AppColors.border;
    final backgroundColor =
        selected ? AppColors.accent.withValues(alpha: 0.10) : AppColors.surface;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? AppColors.mainDark : AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: selected ? AppColors.accent : AppColors.muted,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
