import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() =>
      _RegisterPageState();
}

class _RegisterPageState
    extends State<RegisterPage> {
  final _nameController =
  TextEditingController();

  final _emailController =
  TextEditingController();

  final _passwordController =
  TextEditingController();

  final _confirmPasswordController =
  TextEditingController();

  final AuthService _authService =
  AuthService();

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  String? _message;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    final fullName =
    _nameController.text.trim();

    final email =
    _emailController.text.trim();

    final password =
    _passwordController.text.trim();

    final confirmPassword =
    _confirmPasswordController.text
        .trim();

    if (fullName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        _message =
        'Lütfen tüm alanları doldurun.';
      });

      return;
    }

    final emailRegex =
    RegExp(r'^[^@]+@[^@]+\.[^@]+');

    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _message =
        'Lütfen geçerli bir e-posta adresi girin.';
      });

      return;
    }

    if (password.length < 6) {
      setState(() {
        _message =
        'Şifre en az 6 karakter olmalıdır.';
      });

      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _message =
        'Şifreler birbiriyle eşleşmiyor.';
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final success =
    await _authService.register(
      fullName: fullName,
      email: email,
      password: password,
      role: 'Customer',
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text('Kayıt başarılı.'),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
          const LoginPage(),
        ),
      );
    } else {
      setState(() {
        _message =
        'Kayıt başarısız.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      AppColors.background,
      body: Column(
        children: [
          const TopVisual(
            headline: 'Aramıza\nkatılın',
            subtitle:
            'Ücretsiz hesabınızı dakikada oluşturun',
            tag: 'ÜCRETSİZ',
          ),
          Expanded(
            child: Container(
              decoration:
              const BoxDecoration(
                color:
                AppColors.background,
                borderRadius:
                BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child:
              SingleChildScrollView(
                padding:
                const EdgeInsets.fromLTRB(
                  22,
                  20,
                  22,
                  32,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    SegmentBar(
                      selected: 1,
                      onTap: (i) {
                        if (i == 0) {
                          Navigator
                              .pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                              const LoginPage(),
                            ),
                          );
                        }
                      },
                    ),

                    const SizedBox(
                        height: 20),

                    const FieldLabel(
                        text:
                        'Ad Soyad'),

                    const SizedBox(
                        height: 6),

                    AppTextField(
                      controller:
                      _nameController,
                      hint:
                      'Adınız Soyadınız',
                    ),

                    const SizedBox(
                        height: 13),

                    const FieldLabel(
                        text:
                        'E-posta'),

                    const SizedBox(
                        height: 6),

                    AppTextField(
                      controller:
                      _emailController,
                      hint:
                      'ornek@email.com',
                      keyboardType:
                      TextInputType
                          .emailAddress,
                    ),

                    const SizedBox(
                        height: 13),

                    const FieldLabel(
                        text: 'Şifre'),

                    const SizedBox(
                        height: 6),

                    AppTextField(
                      controller:
                      _passwordController,
                      hint:
                      '••••••••',
                      obscureText:
                      _obscurePass,
                    ),

                    const SizedBox(
                        height: 13),

                    const FieldLabel(
                        text:
                        'Şifre Tekrar'),

                    const SizedBox(
                        height: 6),

                    AppTextField(
                      controller:
                      _confirmPasswordController,
                      hint:
                      '••••••••',
                      obscureText:
                      _obscureConfirm,
                    ),

                    const SizedBox(
                        height: 16),

                    if (_message != null)
                      ...[
                        ErrorBanner(
                            message:
                            _message!),
                        const SizedBox(
                            height: 14),
                      ],

                    _isLoading
                        ? const Center(
                      child:
                      CircularProgressIndicator(),
                    )
                        : PrimaryButton(
                      label:
                      'Hesap oluştur',
                      onTap:
                      _register,
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