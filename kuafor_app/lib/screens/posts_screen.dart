import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/post_service.dart';
import '../widgets/app_widgets.dart';

class PostsScreen extends StatefulWidget {
  final int salonId;
  final bool isOwner;

  const PostsScreen({
    super.key,
    required this.salonId,
    this.isOwner = false,
  });

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  final PostService _postService = PostService();

  List<Map<String, dynamic>> _posts = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);

    final posts =
        await _postService.getPostsBySalon(widget.salonId);

    setState(() {
      _posts = posts;
      _loading = false;
    });
  }

  void _showCreatePostDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    String selectedCategory = 'Genel';

    final List<Map<String, dynamic>> selectedImages = [];

    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Yeni Gönderi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Başlık *',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Açıklama',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Kategori',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 8,
                        children: [
                          'Genel',
                          'BeforeAfter',
                          'Kampanya'
                        ]
                            .map(
                              (cat) => ChoiceChip(
                                label: Text(cat),
                                selected:
                                    selectedCategory == cat,
                                selectedColor:
                                    AppColors.primary,
                                labelStyle: TextStyle(
                                  color:
                                      selectedCategory == cat
                                          ? Colors.white
                                          : Colors.black,
                                ),
                                onSelected: (_) {
                                  setModalState(() {
                                    selectedCategory = cat;
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Fotoğraflar',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 8),

                      if (selectedImages.isNotEmpty)
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection:
                                Axis.horizontal,
                            itemCount:
                                selectedImages.length,
                            itemBuilder: (_, i) => Stack(
                              children: [
                                Container(
                                  margin:
                                      const EdgeInsets.only(
                                          right: 8),
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(
                                            8),
                                    image: DecorationImage(
                                      image: FileImage(
                                        File(selectedImages[i]
                                            ['path']),
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 8),

                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked =
                              await picker.pickMultiImage();

                          if (picked.isNotEmpty) {
                            setModalState(() {
                              for (int i = 0;
                                  i < picked.length;
                                  i++) {
                                selectedImages.add({
                                  'path': picked[i].path,
                                });
                              }
                            });
                          }
                        },
                        icon: const Icon(
                          Icons.add_photo_alternate,
                        ),
                        label:
                            const Text('Fotoğraf Ekle'),
                        style: OutlinedButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(44),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(context)
                          .viewInsets
                          .bottom +
                      16,
                ),
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text
                        .trim()
                        .isEmpty) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content:
                              Text('Başlık gerekli'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(ctx);

                    await _createPostWithImages(
                      title: titleCtrl.text.trim(),
                      description:
                          descCtrl.text.trim(),
                      category: selectedCategory,
                      images: selectedImages,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        AppColors.primary,
                    minimumSize:
                        const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Yayınla',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createPostWithImages({
    required String title,
    required String description,
    required String category,
    required List<Map<String, dynamic>> images,
  }) async {
    final postId = await _postService.createPost(
      title: title,
      description:
          description.isEmpty ? null : description,
      category: category,
      salonId: widget.salonId,
    );

    if (postId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Gönderi oluşturulamadı'),
          ),
        );
      }
      return;
    }

    for (final img in images) {
      await _postService.uploadPostImage(
        postId: postId,
        filePath: img['path'],
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gönderi yayınlandı ✓'),
        ),
      );

      _loadPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text('Gönderiler'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,

        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _posts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Henüz gönderi yok',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),

                        if (widget.isOwner) ...[
                          const SizedBox(height: 12),

                          ElevatedButton.icon(
                            onPressed:
                                _showCreatePostDialog,
                            icon:
                                const Icon(Icons.add),
                            label: const Text(
                              'İlk gönderiyi oluştur',
                            ),
                            style:
                                ElevatedButton.styleFrom(
                              backgroundColor:
                                  AppColors.primary,
                              foregroundColor:
                                  Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadPosts,
                    child: GridView.builder(
                      padding:
                          const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _posts.length,
                      itemBuilder: (_, i) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(
                                    12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(0.08),
                                blurRadius: 8,
                                offset:
                                    const Offset(0, 2),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
      ),

      floatingActionButton:
          widget.isOwner && _posts.isNotEmpty
              ? FloatingActionButton(
                  onPressed:
                      _showCreatePostDialog,
                  backgroundColor:
                      AppColors.primary,
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                  ),
                )
              : null,
    );
  }
}