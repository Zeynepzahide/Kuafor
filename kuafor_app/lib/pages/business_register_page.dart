import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/places_service.dart';
import '../widgets/app_widgets.dart';
import 'login_page.dart';

const _trialOfferText = 'İlk 90 gün ücretsiz';
const _monthlyOfferText = 'Sonra aylık ₺299';

class BusinessRegisterPage extends StatefulWidget {
  const BusinessRegisterPage({super.key});

  @override
  State<BusinessRegisterPage> createState() => _BusinessRegisterPageState();
}

class _BusinessRegisterPageState extends State<BusinessRegisterPage> {
  final _authService = AuthService();
  final _placesService = PlacesService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _salonNameController = TextEditingController();
  final _salonAddressController = TextEditingController();
  final _salonAddressDetailController = TextEditingController();
  final _businessPromptController = TextEditingController();
  final _addressFocus = FocusNode();

  bool _loading = false;
  bool _loadingSuggestions = false;
  bool _addressLocked = false;
  bool _locationConfirmed = false;
  bool _obscurePass = true;
  String? _message;
  String? _proposal;
  double? _salonLat;
  double? _salonLng;
  List<PlacePrediction> _suggestions = [];
  Timer? _debounce;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _salonNameController.dispose();
    _salonAddressController.dispose();
    _salonAddressDetailController.dispose();
    _businessPromptController.dispose();
    _addressFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onAddressChanged(String value) {
    if (_locationConfirmed || _addressLocked) {
      setState(() {
        _addressLocked = false;
        _locationConfirmed = false;
        _salonLat = null;
        _salonLng = null;
      });
    }

    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() {
        _loadingSuggestions = true;
        _message = null;
      });
      final results = await _placesService.getSuggestions(trimmed);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _loadingSuggestions = false;
      });
    });
  }

  Future<void> _selectSuggestion(PlacePrediction prediction) async {
    _debounce?.cancel();
    _salonAddressController.text = prediction.description;
    setState(() {
      _suggestions = [];
      _locationConfirmed = false;
      _addressLocked = false;
      _salonLat = null;
      _salonLng = null;
      _loadingSuggestions = false;
    });
    _addressFocus.unfocus();

    if (prediction.latitude != null && prediction.longitude != null) {
      setState(() {
        _salonLat = prediction.latitude;
        _salonLng = prediction.longitude;
        _locationConfirmed = true;
        _addressLocked = true;
      });
    } else {
      setState(() => _loadingSuggestions = true);
      final detail = await _placesService.getDetail(prediction.placeId);
      if (!mounted) return;
      if (detail != null) {
        setState(() {
          _salonAddressController.text = detail.formattedAddress;
          _salonLat = detail.latitude;
          _salonLng = detail.longitude;
          _locationConfirmed = true;
          _addressLocked = true;
        });
      }
      setState(() => _loadingSuggestions = false);
    }

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) FocusScope.of(context).nextFocus();
    });
  }

  void _clearAddress() {
    setState(() {
      _salonAddressController.clear();
      _salonAddressDetailController.clear();
      _suggestions = [];
      _addressLocked = false;
      _locationConfirmed = false;
      _salonLat = null;
      _salonLng = null;
    });
    _addressFocus.requestFocus();
  }

  String get _fullAddress {
    final base = _salonAddressController.text.trim();
    final detail = _salonAddressDetailController.text.trim();
    if (detail.isEmpty) return base;
    return '$base, $detail';
  }

  void _generateProposal() {
    final ownerName = _nameController.text.trim();
    final salonName = _salonNameController.text.trim();
    final address = _fullAddress;
    final prompt = _businessPromptController.text.trim();

    final displaySalonName = salonName.isEmpty ? 'Yeni salon' : salonName;
    final location = address.isEmpty ? 'belirtilen bölgede' : address;
    final detail =
        prompt.isEmpty
            ? 'randevu yönetimi, hizmet takibi ve müşteri iletişimini tek yerden yürüten modern bir işletme'
            : prompt;

    setState(() {
      _proposal =
          '$displaySalonName, $location hizmet verecek bir güzellik işletmesi olarak başvuruyor. '
          'İşletme profili $detail odağında hazırlanacak. '
          'Lansman teklifi $_trialOfferText, $_monthlyOfferText olarak sunulacak. '
          'Başvuru onaylandığında işletme sahibi ${ownerName.isEmpty ? 'yetkili kullanıcı' : ownerName}, '
          'salon bilgilerini, çalışanlarını, hizmetlerini ve randevularını panelden yönetebilecek.';
    });
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final salonName = _salonNameController.text.trim();
    final salonAddress = _fullAddress;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _message = 'Ad, e-posta ve şifre zorunludur.');
      return;
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _message = 'Lütfen geçerli bir e-posta adresi girin.');
      return;
    }

    if (password.length < 6) {
      setState(() => _message = 'Şifre en az 6 karakter olmalıdır.');
      return;
    }

    if (salonName.isEmpty) {
      setState(() => _message = 'Salon adı zorunludur.');
      return;
    }

    if (salonAddress.isEmpty) {
      setState(() => _message = 'Salon adresi zorunludur.');
      return;
    }

    var proposal = _proposal;
    if (proposal == null || proposal.trim().isEmpty) {
      _generateProposal();
      proposal = _proposal;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    final ok = await _authService.register(
      fullName: name,
      email: email,
      password: password,
      role: 'SalonOwner',
      salonName: salonName,
      salonAddress: salonAddress,
      salonDescription: proposal,
      salonLatitude: _salonLat,
      salonLongitude: _salonLng,
    );

    if (!mounted) return;

    setState(() => _loading = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşletme hesabı oluşturuldu.')),
      );

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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.primary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'İşletme Başvurusu',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BusinessIntro(),
              const SizedBox(height: 18),
              const _PricingOfferCard(),
              const SizedBox(height: 18),
              _AssistantCard(
                controller: _businessPromptController,
                proposal: _proposal,
                onGenerate: _generateProposal,
              ),
              const SizedBox(height: 18),
              const FieldLabel(text: 'Yetkili kişi'),
              const SizedBox(height: 6),
              AppTextField(
                controller: _nameController,
                hint: 'Ad Soyad',
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
                hint: 'isletme@email.com',
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
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscurePass = !_obscurePass),
                  child: Icon(
                    _obscurePass
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              const FieldLabel(text: 'Salon adı'),
              const SizedBox(height: 6),
              AppTextField(
                controller: _salonNameController,
                hint: 'Salon adınız',
                textInputAction: TextInputAction.next,
                prefix: const Icon(
                  Icons.storefront_outlined,
                  size: 18,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 13),
              const FieldLabel(text: 'Salon adresi'),
              const SizedBox(height: 6),
              if (_addressLocked)
                _LockedAddressRow(
                  address: _salonAddressController.text,
                  onClear: _clearAddress,
                )
              else ...[
                _AddressField(
                  controller: _salonAddressController,
                  focusNode: _addressFocus,
                  onChanged: _onAddressChanged,
                  isLoading: _loadingSuggestions,
                ),
                if (_suggestions.isNotEmpty)
                  _SuggestionList(
                    suggestions: _suggestions,
                    onSelect: _selectSuggestion,
                  ),
              ],
              if (_addressLocked) ...[
                const SizedBox(height: 10),
                AppTextField(
                  controller: _salonAddressDetailController,
                  hint: 'Daire No, Kat, Apartman adı... (isteğe bağlı)',
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _register(),
                  prefix: const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.muted,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (_locationConfirmed && _salonLat != null && _salonLng != null)
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Konum belirlendi. Salon haritada görünecek.',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              else
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppColors.muted,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Aşağıdan bir adres seçin; konum otomatik belirlenir.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              if (_message != null) ...[
                ErrorBanner(message: _message!),
                const SizedBox(height: 14),
              ],
              _loading
                  ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2,
                    ),
                  )
                  : PrimaryButton(
                    label: 'İşletme Hesabı Oluştur',
                    onTap: _register,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessIntro extends StatelessWidget {
  const _BusinessIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.mainDark,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 24),
          SizedBox(height: 12),
          Text(
            'İşletmeni birlikte hazırlayalım',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Salonunu birkaç cümleyle anlat; teklifini ve işletme özetini birlikte hazırlayalım.',
            style: TextStyle(
              color: Color(0xFFD8DEE9),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingOfferCard extends StatelessWidget {
  const _PricingOfferCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_offer_outlined, color: AppColors.accent, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lansman teklifi',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'İlk 90 gün ücretsiz deneyin. Sonrasında işletme paneli, randevu takibi ve hizmet yönetimi için aylık ₺299.',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Ödeme adımı başvuru onayından sonra açılacak.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  final TextEditingController controller;
  final String? proposal;
  final VoidCallback onGenerate;

  const _AssistantCard({
    required this.controller,
    required this.proposal,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.accent,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Akıllı teklif özeti',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              height: 1.35,
            ),
            decoration: InputDecoration(
              hintText:
                  'Örn: Kadın kuaförü, protez tırnak ve gelin saçı hizmeti veriyoruz. Merkezi konumdayız.',
              hintStyle: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.35,
              ),
              filled: true,
              fillColor: AppColors.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: const Text('Teklif hazırla'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (proposal != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                proposal!,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LockedAddressRow extends StatelessWidget {
  final String address;
  final VoidCallback onClear;

  const _LockedAddressRow({required this.address, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.38)),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_rounded, size: 17, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              address,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Değiştir',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool isLoading;

  const _AddressField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      keyboardType: TextInputType.streetAddress,
      style: const TextStyle(fontSize: 14, color: AppColors.primary),
      decoration: InputDecoration(
        hintText: 'Mahalle, sokak adı yazın...',
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
        suffixIcon:
            isLoading
                ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                )
                : const Icon(Icons.search, color: AppColors.muted, size: 20),
        filled: true,
        fillColor: AppColors.surfaceSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  final List<PlacePrediction> suggestions;
  final Future<void> Function(PlacePrediction) onSelect;

  const _SuggestionList({required this.suggestions, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: suggestions.length,
        separatorBuilder:
            (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, index) {
          final suggestion = suggestions[index];
          return InkWell(
            borderRadius:
                index == 0
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : index == suggestions.length - 1
                    ? const BorderRadius.vertical(bottom: Radius.circular(12))
                    : BorderRadius.zero,
            onTap: () => onSelect(suggestion),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 17,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      suggestion.description,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
