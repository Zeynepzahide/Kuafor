// lib/pages/salon_owner_home_page.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/salon_service.dart';
import '../services/appointment_service.dart';
import '../widgets/app_widgets.dart';
import '../screens/notifications_screen.dart';
import '../screens/campaigns_screen.dart';
import '../screens/reviews_readonly_screen.dart';
import '../screens/services_management_screen.dart';
import '../screens/salon_owner_appointments_screen.dart';
import '../screens/employee_management_screen.dart';
import '../screens/salon_info_edit_screen.dart';
import '../screens/posts_screen.dart';
import '../screens/messages_screen.dart';
import 'customer_home_page.dart';
import 'profile_page.dart';

class SalonOwnerHomePage extends StatefulWidget {
  const SalonOwnerHomePage({super.key});

  @override
  State<SalonOwnerHomePage> createState() => _SalonOwnerHomePageState();
}

class _SalonOwnerHomePageState extends State<SalonOwnerHomePage> {
  final AuthService _authService = AuthService();
  final SalonService _salonService = SalonService();
  final AppointmentService _appointmentService = AppointmentService();

  int _userId = 0;
  int _salonId = 0;
  String _userName = '';
  String _salonName = '';
  String _salonAddress = '';
  double? _salonLat;
  double? _salonLng;
  bool _loadingUser = true;
  int _pendingCount = 0;
  int _appointmentCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loadingUser = true);
    final token = await _authService.getToken();
    if (token == null) {
      setState(() => _loadingUser = false);
      return;
    }

    final user = await _authService.getUserInfo(token);
    if (user != null) {
      final userId = user['id'] ?? 0;
      setState(() {
        _userId = userId;
        _userName = user['name'] ?? '';
      });
      final salon = await _salonService.getSalonByOwner(userId);
      if (salon != null) {
        setState(() {
          _salonId = salon['id'] ?? 0;
          _salonName = salon['name'] ?? '';
          _salonAddress = salon['address'] ?? '';
          _salonLat = (salon['latitude'] as num?)?.toDouble();
          _salonLng = (salon['longitude'] as num?)?.toDouble();
        });
        await _loadPendingCount(_salonId);
      }
    }
    setState(() => _loadingUser = false);
  }

  Future<void> _loadPendingCount(int salonId) async {
    try {
      final appointments = await _appointmentService.getSalonAppointments(
        salonId,
      );
      final pending =
          appointments.where((a) {
            final status =
                (a['statusCode'] ?? a['status'] ?? a['Status'] ?? '')
                    .toString();
            return status == 'Pending' || status == 'Beklemede';
          }).length;
      if (mounted) {
        setState(() {
          _pendingCount = pending;
          _appointmentCount = appointments.length;
        });
      }
    } catch (_) {}
  }

  Future<void> _navigate(Widget screen, {bool refreshAfter = false}) async {
    if (_loadingUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bilgiler yükleniyor, lütfen bekleyin...'),
        ),
      );
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    if (refreshAfter && _salonId != 0) {
      await _loadPendingCount(_salonId);
    }
  }

  void _requireSalon(VoidCallback action) {
    if (_loadingUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bilgiler yükleniyor, lütfen bekleyin...'),
        ),
      );
      return;
    }
    if (_salonId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce salon bilgilerinizi tamamlayın.')),
      );
      return;
    }
    action();
  }

  Future<void> _navigateToSalonEdit() async {
    if (_loadingUser) return;
    if (_salonId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salon bilgisi bulunamadı.')),
      );
      return;
    }
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder:
            (_) => SalonInfoEditScreen(
              salonId: _salonId,
              currentName: _salonName,
              currentAddress: _salonAddress,
              currentLat: _salonLat,
              currentLng: _salonLng,
            ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _salonName = result['name'] ?? _salonName;
        _salonAddress = result['address'] ?? _salonAddress;
        _salonLat = result['latitude'] as double?;
        _salonLng = result['longitude'] as double?;
      });
      await _loadPendingCount(_salonId);
    }
  }

  void _openOwnerMessages() {
    _requireSalon(() {
      _navigate(
        MessagesScreen(userId: _userId, salonId: _salonId, ownerMode: true),
        refreshAfter: true,
      );
    });
  }

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await _authService.deleteToken();
    if (!mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const CustomerHomePage(guestMode: true),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SALON SAHİBİ',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _loadingUser
                            ? 'Yükleniyor...'
                            : 'Hoş geldiniz, $_userName',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!_loadingUser && _salonName.isNotEmpty)
                        Text(
                          _salonName,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _navigate(NotificationsScreen(userId: _userId)),
                  child: const _HeaderBtn(icon: Icons.notifications_outlined),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _navigate(const ProfilePage()),
                  child: const _HeaderBtn(icon: Icons.person_outline_rounded),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _logout(context),
                  child: const _HeaderBtn(
                    icon: Icons.logout_rounded,
                    accent: true,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _loadingUser
                    ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                    : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Salon Yönetimi',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _OwnerSummary(
                            pendingCount: _pendingCount,
                            appointmentCount: _appointmentCount,
                            hasLocation: _salonLat != null && _salonLng != null,
                          ),
                          const SizedBox(height: 14),
                          _MenuCard(
                            icon: Icons.edit_location_alt_outlined,
                            title: 'Salon Bilgileri',
                            subtitle:
                                _salonAddress.isNotEmpty
                                    ? _salonAddress
                                    : 'Salon adı ve adresini düzenle',
                            badge: _salonLat == null ? 'Konum yok' : null,
                            badgeColor: Colors.orange,
                            onTap: _navigateToSalonEdit,
                          ),
                          const SizedBox(height: 10),
                          _MenuCard(
                            icon: Icons.photo_library_outlined,
                            title: 'Gönderiler',
                            subtitle: 'Before/after ve çalışmalarını paylaş',
                            onTap:
                                () => _requireSalon(
                                  () => _navigate(
                                    PostsScreen(
                                      salonId: _salonId,
                                      isOwner: true,
                                    ),
                                  ),
                                ),
                          ),
                          const SizedBox(height: 10),
                          _MenuCard(
                            icon: Icons.people_outline_rounded,
                            title: 'Çalışanlar',
                            subtitle: 'Kuaförlerini ve personelini yönet',
                            onTap:
                                () => _requireSalon(
                                  () => _navigate(
                                    EmployeeManagementScreen(salonId: _salonId),
                                  ),
                                ),
                          ),
                          const SizedBox(height: 10),
                          _MenuCard(
                            icon: Icons.content_cut_rounded,
                            title: 'Hizmetler',
                            subtitle:
                                'Salon hizmetlerini düzenle ve fiyatlandır',
                            onTap:
                                () => _requireSalon(
                                  () => _navigate(
                                    ServicesManagementScreen(salonId: _salonId),
                                  ),
                                ),
                          ),
                          const SizedBox(height: 10),
                          _MenuCard(
                            icon: Icons.calendar_month_outlined,
                            title: 'Randevular',
                            subtitle: 'Tüm salon randevularını görüntüle',
                            pendingCount: _pendingCount,
                            onTap:
                                () => _requireSalon(
                                  () => _navigate(
                                    SalonOwnerAppointmentsScreen(
                                      salonId: _salonId,
                                    ),
                                    refreshAfter: true,
                                  ),
                                ),
                          ),
                          const SizedBox(height: 10),
                          _MenuCard(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'Mesajlar',
                            subtitle: 'Randevulu müşterilerle yazış',
                            badge:
                                _appointmentCount > 0
                                    ? '$_appointmentCount'
                                    : null,
                            badgeColor: AppColors.accent,
                            onTap: _openOwnerMessages,
                          ),
                          const SizedBox(height: 10),
                          _MenuCard(
                            icon: Icons.campaign_outlined,
                            title: 'Kampanyalar',
                            subtitle: 'Aktif kampanyaları görüntüle ve yönet',
                            onTap:
                                () => _requireSalon(
                                  () => _navigate(
                                    CampaignsScreen(salonId: _salonId),
                                  ),
                                ),
                          ),
                          const SizedBox(height: 10),
                          _MenuCard(
                            icon: Icons.star_outline_rounded,
                            title: 'Yorumlar',
                            subtitle: 'Müşteri yorumlarını takip et',
                            onTap:
                                () => _requireSalon(
                                  () => _navigate(
                                    ReviewsReadOnlyScreen(salonId: _salonId),
                                  ),
                                ),
                          ),
                          const SizedBox(height: 10),
                          _MenuCard(
                            icon: Icons.notifications_outlined,
                            title: 'Bildirimler',
                            subtitle: 'Salon bildirimlerini görüntüle',
                            onTap:
                                () => _navigate(
                                  NotificationsScreen(userId: _userId),
                                ),
                          ),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _OwnerSummary extends StatelessWidget {
  final int pendingCount;
  final int appointmentCount;
  final bool hasLocation;

  const _OwnerSummary({
    required this.pendingCount,
    required this.appointmentCount,
    required this.hasLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryPill(
          icon: Icons.pending_actions_rounded,
          label: 'Bekleyen',
          value: '$pendingCount',
          color: pendingCount > 0 ? Colors.orange : AppColors.accent,
        ),
        const SizedBox(width: 8),
        _SummaryPill(
          icon: Icons.calendar_month_outlined,
          label: 'Randevu',
          value: '$appointmentCount',
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        _SummaryPill(
          icon: hasLocation ? Icons.location_on_outlined : Icons.location_off,
          label: 'Konum',
          value: hasLocation ? 'Var' : 'Yok',
          color: hasLocation ? const Color(0xFF10B981) : Colors.orange,
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final bool accent;
  const _HeaderBtn({required this.icon, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Icon(
        icon,
        color: accent ? AppColors.accent : AppColors.white,
        size: 20,
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final int pendingCount;
  final String? badge;
  final Color badgeColor;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.pendingCount = 0,
    this.badge,
    this.badgeColor = Colors.orange,
  });

  @override
  Widget build(BuildContext context) {
    final hasBadge = pendingCount > 0 || badge != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                hasBadge ? badgeColor.withValues(alpha: 0.5) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (pendingCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+$pendingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ] else if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
