import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  String? _message;
  bool _isSuccess = false;
  bool _isLoading = false;

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _message = 'Lütfen e-posta adresinizi girin.');
      return;
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _message = 'Lütfen geçerli bir e-posta adresi girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
      _isSuccess = false;
    });

    final result = await _authService.forgotPassword(email);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _message = result.message;
      _isSuccess = result.isSuccess;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const TopVisual(
            headline: 'Şifrenizi\nsıfırlayın',
            subtitle: 'E-posta adresinizi girin, size bağlantı gönderelim',
            tag: 'YARDIM',
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
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Girişe dön',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    const FieldLabel(text: 'E-posta'),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _emailController,
                      hint: 'ornek@email.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _sendResetLink(),
                      prefix: const Icon(
                        Icons.mail_outline_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 18),

                    if (_message != null) ...[
                      _isSuccess
                          ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              _message!,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          : ErrorBanner(message: _message!),
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
                          label: 'Sıfırlama bağlantısı gönder',
                          onTap: _sendResetLink,
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
