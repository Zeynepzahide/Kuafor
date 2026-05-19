import 'package:flutter/material.dart';
import '../services/salon_service.dart';
import '../services/review_service.dart';
import '../screens/booking_screen.dart';
import '../screens/posts_screen.dart';
import '../widgets/app_widgets.dart';

class SalonDetailScreen extends StatefulWidget {
  final int salonId;
  final int userId;
 final String salonName;

  const SalonDetailScreen({
    super.key,
    required this.salonId,
    required this.userId,
    required this.salonName,
  });

  @override
  State<SalonDetailScreen> createState() =>
      _SalonDetailScreenState();
}

class _SalonDetailScreenState
    extends State<SalonDetailScreen>
    with SingleTickerProviderStateMixin {
  final SalonService _salonService =
      SalonService();

  final ReviewService _reviewService =
      ReviewService();

  late TabController _tabController;

  late Future<Map<String, dynamic>?>
      _salonFuture;

  late Future<List<dynamic>>
      _reviewsFuture;

  final TextEditingController
      _commentController =
      TextEditingController();

  int _selectedRating = 5;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
    );

    _salonFuture = _salonService
        .getSalonDetail(widget.salonId);

    _loadReviews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _loadReviews() {
    setState(() {
      _reviewsFuture =
          _reviewService.getSalonReviews(
        widget.salonId,
      );
    });
  }

  // ─────────────────────────────────────────
  // YORUM GÖNDER
  // ─────────────────────────────────────────

  Future<void> _submitReview() async {
    // BOŞ YORUM KONTROLÜ
    if (_commentController.text
        .trim()
        .isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('Yorum boş olamaz'),
        ),
      );

      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success =
          await _reviewService.addReview(
        salonId: widget.salonId,
        userId: widget.userId,
        rating: _selectedRating,
        comment: _commentController.text
            .trim(),
      );

      setState(() {
        _isSubmitting = false;
      });

      // BAŞARILI
      if (success) {
        _commentController.clear();

        setState(() {
          _selectedRating = 5;
        });

        _loadReviews();

        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Yorumunuz başarıyla eklendi ✓',
            ),
            backgroundColor:
                Color(0xFF0F172A),
          ),
        );
      } else {
        // HİZMET ALMAMIŞ
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Yorum yapabilmek için bu salondan hizmet almanız gerekir.',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Yorum yapabilmek için tamamlanmış randevunuz olmalıdır.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: Column(
        children: [
          // ───────────────── HEADER ─────────────────

          Container(
            color: AppColors.primary,

            padding: EdgeInsets.only(
              top:
                  MediaQuery.of(context)
                          .padding
                          .top +
                      16,
              left: 24,
              right: 24,
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          Navigator.pop(
                              context),

                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [
                          const Text(
                            'SALON',

                            style: TextStyle(
                              color:
                                  AppColors
                                      .accent,
                              fontSize: 11,
                              fontWeight:
                                  FontWeight
                                      .w600,
                              letterSpacing:
                                  2.5,
                            ),
                          ),

                          const SizedBox(
                              height: 2),

                          Text(
                            widget.salonName,

                            style:
                                const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight:
                                  FontWeight
                                      .w500,
                            ),

                            overflow:
                                TextOverflow
                                    .ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ───────── TABBAR ─────────

                TabBar(
                  controller: _tabController,

                  indicatorColor:
                      AppColors.accent,

                  indicatorWeight: 3,

                  labelColor:
                      Colors.white,

                  unselectedLabelColor:
                      Colors.white54,

                  tabs: const [
                    Tab(
                        text:
                            'Hizmetler'),
                    Tab(
                        text:
                            'Gönderiler'),
                    Tab(
                        text:
                            'Yorumlar'),
                  ],
                ),
              ],
            ),
          ),

          // ───────────────── İÇERİK ─────────────────

          Expanded(
            child:
                FutureBuilder<
                    Map<String,
                        dynamic>?>(
              future: _salonFuture,

              builder:
                  (context, snapshot) {
                if (snapshot
                        .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                final salon =
                    snapshot.data;

                final services =
                    (salon?['services']
                            as List<dynamic>?) ??
                        [];

                return TabBarView(
                  controller:
                      _tabController,

                  children: [

                    // ───────── HİZMETLER ─────────

                    ListView(
                      padding:
                          const EdgeInsets
                              .all(16),

                      children: [
                        if (services
                            .isEmpty)
                          Container(
                            padding:
                                const EdgeInsets
                                    .all(20),

                            decoration:
                                BoxDecoration(
                              color: Colors
                                  .white,

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                          14),
                            ),

                            child:
                                const Center(
                              child: Text(
                                'Henüz hizmet eklenmemiş',
                              ),
                            ),
                          )
                        else
                          ...services
                              .map(
                                (service) =>
                                    Container(
                                  margin:
                                      const EdgeInsets
                                          .only(
                                              bottom:
                                                  8),

                                  padding:
                                      const EdgeInsets
                                          .all(
                                              16),

                                  decoration:
                                      BoxDecoration(
                                    color: Colors
                                        .white,

                                    borderRadius:
                                        BorderRadius.circular(
                                            14),
                                  ),

                                  child:
                                      Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,

                                    children: [
                                      Text(
                                        service[
                                                'name'] ??
                                            '',

                                        style:
                                            const TextStyle(
                                          fontSize:
                                              16,
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),

                                      const SizedBox(
                                          height:
                                              8),

                                      Text(
                                        '₺${service['price']}',
                                      ),

                                      const SizedBox(
                                          height:
                                              12),

                                      GestureDetector(
                                        onTap:
                                            () {
                                          Navigator
                                              .push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) =>
                                                      BookingScreen(
                                                customerId:
                                                    widget.userId,

                                                salonId:
                                                    widget.salonId,

                                                salonName:
                                                    widget.salonName,

                                                serviceId:
                                                    service['id'],

                                                serviceName:
                                                    service['name'],

                                                servicePrice:
                                                    (service['price'] as num)
                                                        .toDouble(),

                                                serviceDurationMinutes:
                                                    service['durationMinutes'],
                                              ),
                                            ),
                                          );
                                        },

                                        child:
                                            Container(
                                          width:
                                              double.infinity,

                                          padding:
                                              const EdgeInsets.symmetric(
                                            vertical:
                                                12,
                                          ),

                                          decoration:
                                              BoxDecoration(
                                            color:
                                                AppColors.primary,

                                            borderRadius:
                                                BorderRadius.circular(
                                                    12),
                                          ),

                                          child:
                                              const Center(
                                            child:
                                                Text(
                                              'Randevu Al',

                                              style:
                                                  TextStyle(
                                                color:
                                                    Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                      ],
                    ),

                    // ───────── GÖNDERİLER ─────────

                    Container(
                      color: Colors.white,

                      child: PostsScreen(
                        salonId:
                            widget.salonId,
                        isOwner: false,
                      ),
                    ),

                    // ───────── YORUMLAR ─────────

                    ListView(
                      padding:
                          const EdgeInsets
                              .all(16),

                      children: [

                        const Text(
                          'YORUM YAZ',

                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),

                        const SizedBox(
                            height: 10),

                        // BİLGİ MESAJI

                        Container(
                          padding:
                              const EdgeInsets
                                  .all(12),

                          decoration:
                              BoxDecoration(
                            color: Colors
                                .orange
                                .shade50,

                            borderRadius:
                                BorderRadius
                                    .circular(
                                        12),
                          ),

                          child:
                              const Row(
                            children: [
                              Icon(
                                Icons
                                    .info_outline,
                                color: Colors
                                    .orange,
                              ),

                              SizedBox(
                                  width: 8),

                              Expanded(
                                child: Text(
                                  'Yalnızca hizmet alan müşteriler yorum yapabilir.',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                            height: 12),

                        // YORUM KUTUSU

                        Container(
                          padding:
                              const EdgeInsets
                                  .all(16),

                          decoration:
                              BoxDecoration(
                            color:
                                Colors.white,

                            borderRadius:
                                BorderRadius
                                    .circular(
                                        14),
                          ),

                          child:
                              Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                            children: [

                              // YILDIZLAR

                              Row(
                                children:
                                    List.generate(
                                  5,
                                  (i) {
                                    final star =
                                        i + 1;

                                    return GestureDetector(
                                      onTap:
                                          () {
                                        setState(
                                            () {
                                          _selectedRating =
                                              star;
                                        });
                                      },

                                      child:
                                          Icon(
                                        star <=
                                                _selectedRating
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,

                                        color: star <=
                                                _selectedRating
                                            ? Colors.amber
                                            : Colors.grey,

                                        size:
                                            28,
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(
                                  height:
                                      10),

                              // TEXTFIELD

                              TextField(
                                controller:
                                    _commentController,

                                maxLines:
                                    3,

                                decoration:
                                    InputDecoration(
                                  hintText:
                                      'Deneyiminizi paylaşın...',

                                  filled:
                                      true,

                                  fillColor:
                                      Colors.grey
                                          .shade100,

                                  border:
                                      OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                            12),

                                    borderSide:
                                        BorderSide.none,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                  height:
                                      12),

                              // GÖNDER BUTONU

                              GestureDetector(
                                onTap:
                                    _isSubmitting
                                        ? null
                                        : _submitReview,

                                child:
                                    Container(
                                  width:
                                      double.infinity,

                                  padding:
                                      const EdgeInsets.symmetric(
                                    vertical:
                                        14,
                                  ),

                                  decoration:
                                      BoxDecoration(
                                    color:
                                        AppColors.primary,

                                    borderRadius:
                                        BorderRadius.circular(
                                            12),
                                  ),

                                  child:
                                      Center(
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width:
                                                18,
                                            height:
                                                18,

                                            child:
                                                CircularProgressIndicator(
                                              color:
                                                  Colors.white,
                                              strokeWidth:
                                                  2,
                                            ),
                                          )
                                        : const Text(
                                            'Gönder',

                                            style:
                                                TextStyle(
                                              color:
                                                  Colors.white,

                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                            height: 20),

                        // MÜŞTERİ YORUMLARI

                        FutureBuilder<
                            List<dynamic>>(
                          future:
                              _reviewsFuture,

                          builder:
                              (context,
                                  snap) {

                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child:
                                    CircularProgressIndicator(),
                              );
                            }

                            if (!snap.hasData ||
                                snap.data!
                                    .isEmpty) {
                              return Container(
                                padding:
                                    const EdgeInsets.all(
                                        20),

                                decoration:
                                    BoxDecoration(
                                  color: Colors
                                      .white,

                                  borderRadius:
                                      BorderRadius.circular(
                                          14),
                                ),

                                child:
                                    const Center(
                                  child: Text(
                                    'Henüz yorum yok',
                                  ),
                                ),
                              );
                            }

                            return Column(
                              children:
                                  snap.data!
                                      .map(
                                (review) {

                                  final rating =
                                      review[
                                              'rating'] ??
                                          0;

                                  final name =
                                      review['user']
                                              ?[
                                              'fullName'] ??
                                          'Kullanıcı';

                                  return Container(
                                    margin:
                                        const EdgeInsets.only(
                                            bottom:
                                                8),

                                    padding:
                                        const EdgeInsets.all(
                                            14),

                                    decoration:
                                        BoxDecoration(
                                      color:
                                          Colors.white,

                                      borderRadius:
                                          BorderRadius.circular(
                                              14),
                                    ),

                                    child:
                                        Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                      children: [

                                        Row(
                                          children: [

                                            Expanded(
                                              child:
                                                  Text(
                                                name,

                                                style:
                                                    const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                            ),

                                            Row(
                                              children:
                                                  List.generate(
                                                5,
                                                (i) =>
                                                    Icon(
                                                  i < rating
                                                      ? Icons.star_rounded
                                                      : Icons.star_outline_rounded,

                                                  color:
                                                      Colors.amber,

                                                  size:
                                                      16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(
                                            height:
                                                8),

                                        Text(
                                          review[
                                                  'comment'] ??
                                              '',
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}