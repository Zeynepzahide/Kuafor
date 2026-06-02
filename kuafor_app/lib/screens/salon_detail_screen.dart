import 'package:flutter/material.dart';
import '../services/post_service.dart';
import '../services/review_service.dart';
import '../services/salon_service.dart';
import '../screens/booking_screen.dart';
import '../screens/messages_screen.dart';
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
  State<SalonDetailScreen> createState() => _SalonDetailScreenState();
}

class _SalonDetailScreenState extends State<SalonDetailScreen>
    with SingleTickerProviderStateMixin {
  final SalonService _salonService = SalonService();
  final ReviewService _reviewService = ReviewService();
  final PostService _postService = PostService();
  final TextEditingController _commentController = TextEditingController();

  late final TabController _tabController;
  late Future<Map<String, dynamic>?> _salonFuture;
  late Future<List<dynamic>> _reviewsFuture;
  late Future<List<Map<String, dynamic>>> _postsFuture;

  int _selectedRating = 5;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _salonFuture = _salonService.getSalonDetail(widget.salonId);
    _postsFuture = _postService.getPostsBySalon(widget.salonId);
    _loadReviews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _loadReviews() {
    _reviewsFuture = _reviewService.getSalonReviews(widget.salonId);
  }

  Future<void> _submitReview() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Yorum boş olamaz')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await _reviewService.addReview(
        salonId: widget.salonId,
        userId: widget.userId,
        rating: _selectedRating,
        comment: _commentController.text.trim(),
      );

      if (!mounted) return;

      setState(() => _isSubmitting = false);

      if (success) {
        _commentController.clear();
        setState(() {
          _selectedRating = 5;
          _loadReviews();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yorumunuz başarıyla eklendi'),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Yorum yapabilmek için bu salondan hizmet almanız gerekir.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Yorum yapabilmek için tamamlanmış randevunuz olmalıdır.',
          ),
        ),
      );
    }
  }

  void _openInquiryMessage() {
    if (widget.userId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesaj göndermek için giriş yapın.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => MessagesScreen(
              userId: widget.userId,
              initialSalonId: widget.salonId,
              initialSalonName: widget.salonName,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _salonFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          final salon = snapshot.data;
          final services = (salon?['services'] as List<dynamic>?) ?? [];

          return Column(
            children: [
              _ProfileHeader(
                salon: salon,
                fallbackName: widget.salonName,
                servicesCount: services.length,
                reviewsFuture: _reviewsFuture,
                postsFuture: _postsFuture,
                tabController: _tabController,
                onMessageTap: _openInquiryMessage,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildServicesTab(services),
                    PostsScreen(
                      salonId: widget.salonId,
                      isOwner: false,
                      embedded: true,
                    ),
                    _buildReviewsTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildServicesTab(List<dynamic> services) {
    if (services.isEmpty) {
      return const _EmptyState(
        icon: Icons.content_cut_rounded,
        title: 'Henüz hizmet eklenmemiş',
        message: 'Salon hizmet eklediğinde burada görünecek.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: services.length,
      itemBuilder:
          (context, index) => _ServiceCard(
            service: services[index],
            onBook: () {
              final service = services[index];
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => BookingScreen(
                        customerId: widget.userId,
                        salonId: widget.salonId,
                        salonName: widget.salonName,
                        serviceId: service['id'],
                        serviceName: service['name'],
                        servicePrice:
                            ((service['price'] ?? 0) as num).toDouble(),
                        serviceDurationMinutes: service['durationMinutes'],
                      ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildReviewsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _ReviewComposer(
          selectedRating: _selectedRating,
          isSubmitting: _isSubmitting,
          controller: _commentController,
          onRatingChanged: (rating) => setState(() => _selectedRating = rating),
          onSubmit: _submitReview,
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<dynamic>>(
          future: _reviewsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              );
            }

            final reviews = snapshot.data ?? [];
            if (reviews.isEmpty) {
              return const _EmptyState(
                icon: Icons.rate_review_outlined,
                title: 'Henüz yorum yok',
                message: 'İlk deneyim paylaşıldığında burada görünecek.',
                compact: true,
              );
            }

            return Column(
              children:
                  reviews.map((review) => _ReviewCard(review: review)).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic>? salon;
  final String fallbackName;
  final int servicesCount;
  final Future<List<dynamic>> reviewsFuture;
  final Future<List<Map<String, dynamic>>> postsFuture;
  final TabController tabController;
  final VoidCallback onMessageTap;

  const _ProfileHeader({
    required this.salon,
    required this.fallbackName,
    required this.servicesCount,
    required this.reviewsFuture,
    required this.postsFuture,
    required this.tabController,
    required this.onMessageTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final name = (salon?['name'] ?? fallbackName).toString();
    final address = (salon?['address'] ?? '').toString();
    final description = (salon?['description'] ?? '').toString();
    final imageUrl = (salon?['imageUrl'] ?? '').toString();

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: EdgeInsets.only(top: topPadding + 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 38,
                    height: 38,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _SalonAvatar(name: name, imageUrl: imageUrl),
                const SizedBox(width: 18),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatBlock(label: 'Hizmet', value: '$servicesCount'),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: postsFuture,
                        builder:
                            (context, snapshot) => _StatBlock(
                              label: 'Gönderi',
                              value: '${snapshot.data?.length ?? 0}',
                            ),
                      ),
                      FutureBuilder<List<dynamic>>(
                        future: reviewsFuture,
                        builder: (context, snapshot) {
                          final reviews = snapshot.data ?? [];
                          final average = _averageRating(reviews);
                          return _StatBlock(
                            label: 'Puan',
                            value:
                                average == 0 ? '-' : average.toStringAsFixed(1),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (address.isNotEmpty || description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (address.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          color: AppColors.accent,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMessageTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 17,
                    ),
                    label: const Text(
                      'Mesaj',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: tabController,
            indicatorColor: AppColors.accent,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            tabs: const [
              Tab(text: 'Hizmetler'),
              Tab(text: 'Gönderiler'),
              Tab(text: 'Yorumlar'),
            ],
          ),
        ],
      ),
    );
  }

  static double _averageRating(List<dynamic> reviews) {
    if (reviews.isEmpty) return 0;
    final total = reviews.fold<double>(
      0,
      (sum, review) => sum + ((review['rating'] ?? 0) as num).toDouble(),
    );
    return total / reviews.length;
  }
}

class _SalonAvatar extends StatelessWidget {
  final String name;
  final String imageUrl;

  const _SalonAvatar({required this.name, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.accent.withValues(alpha: 0.18),
      child: Center(
        child: Text(
          name.trim().isEmpty ? 'S' : name.trim()[0].toUpperCase(),
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      child: ClipOval(
        child:
            imageUrl.isEmpty
                ? fallback
                : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback,
                ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String value;
  final String label;

  const _StatBlock({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final dynamic service;
  final VoidCallback onBook;

  const _ServiceCard({required this.service, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final name = (service['name'] ?? 'Hizmet').toString();
    final price = ((service['price'] ?? 0) as num).toDouble();
    final duration = service['durationMinutes'];
    final stylistName = (service['stylistName'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.content_cut_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (stylistName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        stylistName,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                _formatPrice(price),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (duration != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: AppColors.muted,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$duration dk',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: onBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Randevu Al',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewComposer extends StatelessWidget {
  final int selectedRating;
  final bool isSubmitting;
  final TextEditingController controller;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmit;

  const _ReviewComposer({
    required this.selectedRating,
    required this.isSubmitting,
    required this.controller,
    required this.onRatingChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yorum yaz',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.accent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Yalnızca hizmet alan müşteriler yorum yapabilir.',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(5, (index) {
              final star = index + 1;
              return GestureDetector(
                onTap: () => onRatingChanged(star),
                child: Icon(
                  star <= selectedRating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 30,
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Deneyiminizi paylaşın...',
              filled: true,
              fillColor: AppColors.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.55,
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  isSubmitting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Text(
                        'Gönder',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final dynamic review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating = ((review['rating'] ?? 0) as num).toInt();
    final name = (review['user']?['fullName'] ?? 'Kullanıcı').toString();
    final comment = (review['comment'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                child: Text(
                  name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              comment,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool compact;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 18 : 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.muted, size: compact ? 40 : 54),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatPrice(double price) {
  if (price % 1 == 0) return '₺${price.toInt()}';
  return '₺${price.toStringAsFixed(2)}';
}
