import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/appointment_service.dart';
import '../services/auth_service.dart';
import '../services/campaign_service.dart';
import '../services/review_service.dart';

import '../widgets/app_widgets.dart';

import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() =>
      _ProfilePageState();
}

class _ProfilePageState
    extends State<ProfilePage> {
  final AuthService _authService =
      AuthService();

  final AppointmentService
      _appointmentService =
      AppointmentService();

  final ReviewService
      _reviewService =
      ReviewService();

  final CampaignService
      _campaignService =
      CampaignService();

  final ImagePicker _picker =
      ImagePicker();

  String name = "";
  String email = "";
  String role = "";

  int _userId = 0;

  int _appointmentCount = 0;
  int _reviewCount = 0;
  int _campaignCount = 0;

  double _averageRating = 0;

  String _profileImageUrl = "";

  bool _isLoading = true;
  bool _isLoggingOut = false;
  bool _uploadingPhoto = false;

  bool _notifOn = true;
  bool _campaignNotif = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }


  Future<void> _loadUser() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final token =
        await _authService.getToken();

    if (token == null ||
        token.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;

        _errorMessage =
            "Oturum bulunamadı.";
      });

      return;
    }

    final user =
        await _authService.getUserInfo(
            token);

    if (!mounted) return;

    if (user != null) {
      setState(() {
        name =
            user['name'] ?? '';

        email =
            user['email'] ?? '';

        role =
            user['role'] ?? '';

        _userId =
            user['id'] ?? 0;

        _profileImageUrl =
            user['profileImageUrl'] ??
                '';

        _isLoading = false;
      });

      _loadStats();
    } else {
      setState(() {
        _isLoading = false;

        _errorMessage =
            "Kullanıcı bilgileri alınamadı.";
      });
    }
  }


  Future<void> _loadStats() async {
    if (_userId == 0) return;

    final appointments =
        await _appointmentService
            .getCustomerAppointments(
                _userId);

    final reviews =
        await _reviewService.getReviews();

    final campaigns =
        await _campaignService
            .getCampaigns();

    final myReviews = reviews
        .where(
          (r) =>
              r['userId'] == _userId,
        )
        .toList();

    double avg = 0;

    if (myReviews.isNotEmpty) {
      final total =
          myReviews.fold<double>(
        0,
        (sum, r) =>
            sum +
            ((r['rating'] ?? 0)
                    as num)
                .toDouble(),
      );

      avg = total / myReviews.length;
    }

    if (!mounted) return;

    setState(() {
      _appointmentCount =
          appointments.length;

      _reviewCount =
          myReviews.length;

      _campaignCount =
          campaigns.length;

      _averageRating = avg;
    });
  }


  void _copyEmail() {
    if (email.isEmpty) return;

    Clipboard.setData(
      ClipboardData(text: email),
    );

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content:
            Text('E-posta kopyalandı'),
      ),
    );
  }


  void _showSupport() {
    showDialog(
      context: context,

      builder: (_) => AlertDialog(
        title: const Text(
          'Yardım & Destek',
        ),

        content: GestureDetector(
          onTap: () async {

            await Clipboard.setData(
              const ClipboardData(
                text:
                    'kuafor.destek@example.com',
              ),
            );

            if (!mounted) return;

            ScaffoldMessenger.of(
                    context)
                .showSnackBar(
              const SnackBar(
                content: Text(
                  'Destek e-postası kopyalandı',
                ),
              ),
            );
          },

          child: const Text(
            'Destek için kuafor.destek@example.com adresine yazabilirsiniz.\n\nDokunarak kopyalayabilirsiniz.',
          ),
        ),

        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),

            child: const Text(
                'Tamam'),
          ),
        ],
      ),
    );
  }


  void _showRateDialog() {
    showDialog(
      context: context,

      builder: (_) => AlertDialog(
        title: const Text(
          'Uygulamayı Değerlendir',
        ),

        content: const Text(
          'Kuaför uygulamasını beğendiyseniz mağazada puanlayabilirsiniz ⭐',
        ),

        actions: [

          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },

            child: const Text(
              'Daha Sonra',
            ),
          ),

          ElevatedButton(
            onPressed: () {

              Navigator.pop(context);

              ScaffoldMessenger.of(
                      context)
                  .showSnackBar(
                const SnackBar(
                  content: Text(
                    'Mağaza yönlendirmesi yakında eklenecek',
                  ),
                ),
              );
            },

            child: const Text(
              'Puan Ver',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.white,

      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color:
                    AppColors.mainDark,
                strokeWidth: 2,
              ),
            )
          : CustomScrollView(
              slivers: [


                SliverToBoxAdapter(
                  child: Container(
                    margin:
                        const EdgeInsets
                            .all(16),

                    padding:
                        const EdgeInsets
                            .all(20),

                    decoration:
                        BoxDecoration(
                      color: AppColors
                          .mainDark,

                      borderRadius:
                          BorderRadius
                              .circular(
                                  24),
                    ),

                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [

                        CircleAvatar(
                          radius: 34,

                          backgroundColor:
                              Colors.white,

                          backgroundImage:
                              _profileImageUrl
                                      .isNotEmpty
                                  ? NetworkImage(
                                      _profileImageUrl,
                                    )
                                  : null,

                          child:
                              _profileImageUrl
                                      .isEmpty
                                  ? Text(
                                      name
                                              .isNotEmpty
                                          ? name[0]
                                              .toUpperCase()
                                          : '?',

                                      style:
                                          const TextStyle(
                                        fontSize:
                                            24,

                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    )
                                  : null,
                        ),

                        const SizedBox(
                            width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                            children: [

                              Text(
                                name
                                        .isNotEmpty
                                    ? name
                                    : 'Kullanıcı',

                                style:
                                    const TextStyle(
                                  color: Colors
                                      .white,

                                  fontSize:
                                      20,

                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),

                              const SizedBox(
                                  height:
                                      6),

                              GestureDetector(
                                onTap:
                                    _copyEmail,

                                child: Text(
                                  email
                                          .isNotEmpty
                                      ? email
                                      : '-',

                                  style:
                                      TextStyle(
                                    color: Colors
                                        .white
                                        .withOpacity(
                                            0.7),
                                  ),
                                ),
                              ),

                              const SizedBox(
                                  height:
                                      12),

                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      12,
                                  vertical:
                                      6,
                                ),

                                decoration:
                                    BoxDecoration(
                                  color:
                                      AppColors
                                          .accent,

                                  borderRadius:
                                      BorderRadius.circular(
                                          20),
                                ),

                                child: Text(
                                  role,

                                  style:
                                      const TextStyle(
                                    color: Colors
                                        .white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),


                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      16,
                      0,
                      16,
                      0,
                    ),

                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [

                        Expanded(
                          child: _StatCard(
                            label:
                                'Randevu',

                            value:
                                '$_appointmentCount',
                          ),
                        ),

                        const SizedBox(
                            width: 8),

                        Expanded(
                          child: _StatCard(
                            label:
                                'Puan',

                            value:
                                _averageRating
                                    .toStringAsFixed(
                                        1),
                          ),
                        ),

                        const SizedBox(
                            width: 8),

                        Expanded(
                          child: _StatCard(
                            label:
                                'Kampanya',

                            value:
                                '$_campaignCount',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .all(16),

                    child: Column(
                      children: [

                        _ProfileButton(
                          icon:
                              Icons.support_agent,
                          title:
                              'Yardım & Destek',
                          onTap:
                              _showSupport,
                        ),

                        const SizedBox(
                            height: 12),

                        _ProfileButton(
                          icon: Icons.star,
                          title:
                              'Uygulamayı Değerlendir',
                          onTap:
                              _showRateDialog,
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