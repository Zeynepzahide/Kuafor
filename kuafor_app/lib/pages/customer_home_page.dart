import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';
import '../services/salon_service.dart';
import '../services/appointment_service.dart';
import '../widgets/app_widgets.dart';
import '../screens/salon_detail_screen.dart';
import '../screens/salons_map_screen.dart';
import '../screens/campaigns_screen.dart';
import '../screens/messages_screen.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'profile_page.dart';
import '../models/recommended_salon_model.dart';
import '../services/recommendation_service.dart';

class CustomerHomePage extends StatefulWidget {
  final bool guestMode;

  const CustomerHomePage({super.key, this.guestMode = false});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final RecommendationService _recommendationService = RecommendationService();

  List<RecommendedSalonModel> recommendedSalons = [];
  bool isLoadingRecommendations = false;
  Timer? _recommendationDebounce;

  final _authService = AuthService();
  final _salonService = SalonService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _userName = '';
  String _profileImageUrl = '';
  int _userId = 0;
  List<dynamic> _salons = [];
  bool _loading = true;
  bool _nearbyMode = false;
  double? _userLat;
  double? _userLng;
  String? _locationError;
  String _searchQuery = '';

  List<dynamic> get _visibleSalons => _salons;

  List<dynamic> get _filteredSalons {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _visibleSalons;

    return _visibleSalons.where((salon) {
      final name = (salon['name'] ?? '').toString().toLowerCase();
      final address = (salon['address'] ?? '').toString().toLowerCase();
      final description = (salon['description'] ?? '').toString().toLowerCase();

      return name.contains(query) ||
          address.contains(query) ||
          description.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _recommendationDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (!widget.guestMode) {
      await _loadUser();
    }

    await _loadLocation();

    if (!widget.guestMode) {
      await loadRecommendedSalons();
    }
  }

  Future<void> loadRecommendedSalons() async {
    if (widget.guestMode) return;

    setState(() {
      isLoadingRecommendations = true;
    });

    try {
      final result = await _recommendationService.getRecommendedSalons(
        latitude: _userLat,
        longitude: _userLng,
        serviceName: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
      );

      if (!mounted) return;

      setState(() {
        recommendedSalons = result;
      });
    } catch (e) {
      debugPrint('Önerilen salonlar alınamadı: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingRecommendations = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });

    if (widget.guestMode) return;

    _recommendationDebounce?.cancel();
    _recommendationDebounce = Timer(const Duration(milliseconds: 600), () {
      loadRecommendedSalons();
    });
  }

  Future<void> _loadUser() async {
    final token = await _authService.getToken();
    if (token == null) return;

    final info = await _authService.getUserInfo(token);

    if (info != null && mounted) {
      setState(() {
        _userName = info['name'] ?? '';
        _userId = info['id'] ?? 0;
        _profileImageUrl = info['profileImageUrl'] ?? '';
      });
    }
  }

  Future<void> _loadLocation() async {
    setState(() => _loading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _locationError = 'Konum servisi kapalı';
        await _loadAllSalons();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationError = 'Konum izni verilmedi';
        await _loadAllSalons();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _userLat = position.latitude;
      _userLng = position.longitude;

      await _loadNearbySalons();
    } catch (e) {
      _locationError = 'Konum alınamadı';
      await _loadAllSalons();
    }
  }

  Future<void> _loadNearbySalons() async {
    if (_userLat == null || _userLng == null) {
      await _loadAllSalons();
      return;
    }

    try {
      final salons = await _salonService.getNearbySalons(
        lat: _userLat!,
        lng: _userLng!,
        radius: 50.0,
      );

      if (mounted) {
        setState(() {
          _salons = salons;
          _nearbyMode = true;
          _loading = false;
        });
      }
    } catch (e) {
      await _loadAllSalons();
    }
  }

  Future<void> _loadAllSalons() async {
    try {
      final salons = await _salonService.getSalons();

      if (mounted) {
        setState(() {
          _salons = salons;
          _nearbyMode = false;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openMap() {
    FocusScope.of(context).unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalonsMapScreen(
          salons: _visibleSalons,
          userLat: _userLat,
          userLng: _userLng,
          userId: _userId,
        ),
      ),
    );
  }

  void _requireAuth(VoidCallback action) {
    if (widget.guestMode) {
      _showAuthSheet();
    } else {
      action();
    }
  }

  void _showAuthSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AuthBottomSheet(
        onLogin: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        },
        onRegister: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterPage()),
          );
        },
      ),
    );
  }

  void _openAppointments() {
    _requireAuth(() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _AppointmentsPage(userId: _userId)),
      );
    });
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );

    await _loadUser();

    if (!widget.guestMode) {
      await loadRecommendedSalons();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildActionButtons(),
            _buildRecommendedSalonSection(),
            _buildSalonList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hoş geldiniz,',
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.guestMode ? 'Misafir' : _userName,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          widget.guestMode
              ? TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Giriş Yap',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: _openProfile,
                  child: _ProfileAvatar(
                    name: _userName,
                    imageUrl: _profileImageUrl,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          onSubmitted: (_) {
            _searchFocusNode.unfocus();

            if (!widget.guestMode) {
              loadRecommendedSalons();
            }
          },
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Salon, semt veya hizmet ara',
            hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.accent,
            ),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      _searchFocusNode.unfocus();

                      setState(() {
                        _searchQuery = '';
                      });

                      if (!widget.guestMode) {
                        loadRecommendedSalons();
                      }
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.muted,
                      size: 20,
                    ),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              _actionBtn(
                Icons.calendar_today,
                'Randevularım',
                _openAppointments,
                locked: widget.guestMode,
              ),
              const SizedBox(width: 10),
              _actionBtn(
                Icons.local_offer,
                'Kampanyalar',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CampaignsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _actionBtn(
                Icons.chat_bubble_outline_rounded,
                'Mesajlar',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MessagesScreen(userId: _userId),
                  ),
                ),
                locked: widget.guestMode,
              ),
              const SizedBox(width: 10),
              _actionBtn(Icons.map, 'Haritada Gör', _openMap),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool locked = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: locked ? _showAuthSheet : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: AppColors.accent, size: 22),
                  if (locked)
                    Positioned(
                      top: -4,
                      right: -8,
                      child: Icon(
                        Icons.lock,
                        size: 11,
                        color: AppColors.muted.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedSalonSection() {
    if (widget.guestMode) {
      return const SizedBox.shrink();
    }

    if (isLoadingRecommendations) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    if (recommendedSalons.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  'Senin İçin Önerilen Salonlar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recommendedSalons.length,
              itemBuilder: (context, index) {
                final salon = recommendedSalons[index];

                return Container(
                  width: 270,
                  margin: const EdgeInsets.only(right: 12, bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: AppColors.accent,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              salon.salonName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        salon.address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Öneri Skoru: ${salon.recommendationScore.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          salon.recommendationReason,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                            height: 1.25,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalonList() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nearbyMode ? 'Yakındaki Salonlar' : 'Tüm Salonlar',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      if (_nearbyMode && _userLat != null) ...[
                        const SizedBox(height: 3),
                        const Text(
                          '📍 Konuma göre',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!_loading)
                  TextButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      _nearbyMode ? _loadAllSalons() : _loadNearbySalons();
                    },
                    child: Text(
                      _nearbyMode ? 'Tümünü Gör' : 'Yakındakiler',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_locationError != null && !_nearbyMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '⚠️ $_locationError — tüm salonlar gösteriliyor',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        _filteredSalons.isEmpty ? 1 : _filteredSalons.length,
                    itemBuilder: (_, i) {
                      if (_filteredSalons.isEmpty) {
                        return _searchQuery.trim().isEmpty
                            ? const _EmptySalonResult()
                            : _EmptySearchResult(query: _searchQuery);
                      }

                      return _buildSalonCard(_filteredSalons[i]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalonCard(Map<String, dynamic> salon) {
    final name = salon['name'] ?? 'Salon';
    final address = salon['address'] ?? '';
    final distanceKm = salon['distanceKm'];
    final salonId = salon['id'] ?? 0;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SalonDetailScreen(
              salonId: salonId,
              userId: _userId,
              salonName: name,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.content_cut,
                color: AppColors.accent,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  if (address.isNotEmpty)
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  if (distanceKm != null)
                    Text(
                      '${(distanceKm as num).toDouble().toStringAsFixed(1)} km uzakta',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchResult extends StatelessWidget {
  final String query;

  const _EmptySearchResult({required this.query});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: AppColors.accent,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            '"$query" icin salon bulunamadi',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Salon adi, semt veya adresle tekrar deneyin.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptySalonResult extends StatelessWidget {
  const _EmptySalonResult();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.storefront_outlined, color: AppColors.accent, size: 34),
          SizedBox(height: 10),
          Text(
            'Henüz salon bulunamadı',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            'Canlı salon eklendiğinde burada listelenecek.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String name;
  final String imageUrl;

  const _ProfileAvatar({required this.name, required this.imageUrl});

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';

    final parts = trimmed.split(' ').where((e) => e.isNotEmpty).toList();

    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        _initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: imageUrl.isEmpty
          ? fallback
          : ClipOval(
              child: Image.network(
                imageUrl,
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            ),
    );
  }
}

class _AuthBottomSheet extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const _AuthBottomSheet({required this.onLogin, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Icon(
            Icons.lock_outline_rounded,
            size: 40,
            color: AppColors.accent,
          ),
          const SizedBox(height: 14),
          const Text(
            'Bu işlem için giriş gerekiyor',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Randevu almak ve diğer işlemler için\nhesabınıza giriş yapın.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainDark,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Giriş Yap',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRegister,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: AppColors.mainDark, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Kayıt Ol',
                style: TextStyle(
                  color: AppColors.mainDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentsPage extends StatefulWidget {
  final int userId;

  const _AppointmentsPage({required this.userId});

  @override
  State<_AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<_AppointmentsPage> {
  final AppointmentService _appointmentService = AppointmentService();
  List<dynamic> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final data = await _appointmentService.getCustomerAppointments(
      widget.userId,
    );

    setState(() {
      _appointments = data;
      _loading = false;
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Confirmed':
      case 'Onaylandı':
        return Colors.green;
      case 'Cancelled':
      case 'İptal Edildi':
        return Colors.red;
      case 'Completed':
      case 'Tamamlandı':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Confirmed':
      case 'Onaylandı':
        return 'Onaylandı';
      case 'Cancelled':
      case 'İptal Edildi':
        return 'İptal Edildi';
      case 'Completed':
      case 'Tamamlandı':
        return 'Tamamlandı';
      default:
        return 'Bekliyor';
    }
  }

  Future<void> _cancel(int appointmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Randevuyu İptal Et'),
        content: const Text(
          'Bu randevuyu iptal etmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hayır'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Evet, İptal Et',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await _appointmentService.cancelAppointment(
      appointmentId,
      widget.userId,
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Randevu iptal edildi.')));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'İptal başarısız.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        title: const Text(
          'Randevularım',
          style: TextStyle(color: AppColors.white),
        ),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _appointments.isEmpty
              ? const Center(
                  child: Text(
                    'Henüz randevunuz yok.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _appointments.length,
                    itemBuilder: (context, i) {
                      final a = _appointments[i];

                      final status =
                          (a['statusCode'] ??
                                  a['status'] ??
                                  a['Status'] ??
                                  'Pending')
                              .toString();

                      final salonName =
                          (a['salonName'] ??
                                  a['SalonName'] ??
                                  a['salon']?['name'] ??
                                  a['Salon']?['Name'] ??
                                  '')
                              .toString();

                      final serviceName =
                          (a['serviceName'] ??
                                  a['ServiceName'] ??
                                  a['service']?['name'] ??
                                  a['Service']?['Name'] ??
                                  '')
                              .toString();

                      final dateStr =
                          (a['appointmentDate'] ?? a['AppointmentDate'] ?? '')
                              as String;

                      DateTime? date;

                      try {
                        date = DateTime.parse(dateStr).toLocal();
                      } catch (_) {}

                      final canCancel = status == 'Pending' ||
                          status == 'Beklemede' ||
                          status == 'Confirmed' ||
                          status == 'Onaylandı';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today_rounded,
                                    color: AppColors.accent,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        salonName.isEmpty
                                            ? 'Salon bilgisi bekleniyor'
                                            : salonName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        serviceName.isEmpty
                                            ? 'Hizmet bilgisi bekleniyor'
                                            : serviceName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                      if (date != null) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          '${date.day}.${date.month}.${date.year}'
                                          '  ${date.hour.toString().padLeft(2, '0')}:'
                                          '${date.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(
                                      status,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _statusLabel(status),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _statusColor(status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (canCancel) ...[
                              const SizedBox(height: 10),
                              const Divider(
                                height: 1,
                                color: AppColors.border,
                              ),
                              GestureDetector(
                                onTap: () => _cancel(a['id'] as int),
                                child: const Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cancel_outlined,
                                        size: 14,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Randevuyu İptal Et',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}