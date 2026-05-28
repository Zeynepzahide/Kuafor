import 'package:flutter/material.dart';
import '../widgets/app_widgets.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  static final List<Map<String, dynamic>> _threads = [
    {
      'name': 'Stilist Destek',
      'message':
          'Sifre, randevu ve hesap islemleri icin buradan yardim alabilirsiniz.',
      'time': 'Bugun',
      'badge': 'Destek',
      'icon': Icons.support_agent_rounded,
      'messages': [
        'Merhaba, size nasil yardimci olabiliriz?',
        'Randevu, hesap ve salon islemleriniz icin destek ekibi buradan donus yapacak.',
      ],
    },
    {
      'name': 'Stilist Studio Nisantasi',
      'message': 'Yarin 14:30 icin sac bakimi musaitligi var.',
      'time': '11:20',
      'badge': 'Salon',
      'icon': Icons.storefront_rounded,
      'messages': [
        'Merhaba, sac bakimi icin yarin 14:30 uygun gorunuyor.',
        'Onayladiginizda randevu ekibi sizinle iletisime gececek.',
      ],
    },
    {
      'name': 'Luna Beauty Lounge',
      'message': 'Manikur kampanyamiz hafta ici devam ediyor.',
      'time': 'Dun',
      'badge': 'Kampanya',
      'icon': Icons.local_offer_outlined,
      'messages': [
        'Hafta ici manikur hizmetlerinde kampanyamiz devam ediyor.',
        'Kod: BAKIM15',
      ],
    },
  ];

  void _openThread(BuildContext context, Map<String, dynamic> thread) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ThreadSheet(thread: thread),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mesajlar'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _threads.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          if (index == 0) {
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.22),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ornek mesajlar gosteriliyor. Canli mesaj altyapisi baglaninca salon ve destek yazismalari burada listelenecek.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final thread = _threads[index - 1];
          return GestureDetector(
            onTap: () => _openThread(context, thread),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      thread['icon'] as IconData,
                      color: AppColors.accentDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                thread['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Text(
                              thread['time'] as String,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          thread['message'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
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

class _ThreadSheet extends StatelessWidget {
  final Map<String, dynamic> thread;

  const _ThreadSheet({required this.thread});

  @override
  Widget build(BuildContext context) {
    final messages = List<String>.from(thread['messages'] as List);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    thread['icon'] as IconData,
                    color: AppColors.accentDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread['name'] as String,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        thread['badge'] as String,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...messages.map(
              (message) => Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Mesaj yazma yakinda aktif olacak',
                hintStyle: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.muted,
                  size: 18,
                ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
