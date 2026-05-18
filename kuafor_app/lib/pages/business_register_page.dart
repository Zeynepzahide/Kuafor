import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';
import 'login_page.dart';

class BusinessRegisterPage
    extends StatefulWidget {
  const BusinessRegisterPage(
      {super.key});

  @override
  State<BusinessRegisterPage>
  createState() =>
      _BusinessRegisterPageState();
}

class _BusinessRegisterPageState
    extends State<
        BusinessRegisterPage> {
  final _authService =
  AuthService();

  final _nameController =
  TextEditingController();

  final _emailController =
  TextEditingController();

  final _passwordController =
  TextEditingController();

  final _salonNameController =
  TextEditingController();

  final _salonAddressController =
  TextEditingController();

  String _role = 'SalonOwner';

  bool _loading = false;

  String? _message;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _salonNameController.dispose();
    _salonAddressController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    final name =
    _nameController.text.trim();

    final email =
    _emailController.text.trim();

    final password =
    _passwordController.text.trim();

    final salonName =
    _salonNameController.text
        .trim();

    final salonAddress =
    _salonAddressController.text
        .trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      setState(() {
        _message =
        'Ad, e-posta ve şifre zorunludur.';
      });

      return;
    }

    if (_role == 'SalonOwner' &&
        salonName.isEmpty) {
      setState(() {
        _message =
        'Salon adı zorunludur.';
      });

      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    final ok =
    await _authService.register(
      fullName: name,
      email: email,
      password: password,
      role: _role,
      salonName:
      _role == 'SalonOwner'
          ? salonName
          : null,
      salonAddress:
      _role == 'SalonOwner'
          ? salonAddress
          : null,
    );

    if (!mounted) return;

    setState(() => _loading = false);

    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
              'İşletme hesabı oluşturuldu.'),
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
      body: Center(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.all(20),
          child: Column(
            children: [
              AppTextField(
                controller:
                _nameController,
                hint:
                'Ad Soyad',
              ),

              const SizedBox(height: 12),

              AppTextField(
                controller:
                _emailController,
                hint:
                'E-posta',
              ),

              const SizedBox(height: 12),

              AppTextField(
                controller:
                _passwordController,
                hint:
                'Şifre',
                obscureText: true,
              ),

              const SizedBox(height: 12),

              AppTextField(
                controller:
                _salonNameController,
                hint:
                'Salon Adı',
              ),

              const SizedBox(height: 12),

              AppTextField(
                controller:
                _salonAddressController,
                hint:
                'Salon Adresi',
              ),

              const SizedBox(height: 20),

              if (_message != null)
                ErrorBanner(
                    message: _message!),

              const SizedBox(height: 12),

              _loading
                  ? const CircularProgressIndicator()
                  : PrimaryButton(
                label:
                'İşletme Hesabı Oluştur',
                onTap:
                _register,
              ),
            ],
          ),
        ),
      ),
    );
  }
}