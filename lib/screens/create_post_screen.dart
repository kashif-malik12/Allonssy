import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/post_types.dart';
import '../core/market_categories.dart';
import '../services/post_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentCtrl = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  final _marketTitleCtrl = TextEditingController();
  final _marketPriceCtrl = TextEditingController();

  String _visibility = 'public';
  PostType _selectedPostType = PostType.post;
  String _selectedMarketCategory = marketMainCategories.first;
  String _selectedMarketIntent = 'selling';

  XFile? _imageXFile;
  bool _loading = false;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _contentCtrl.dispose();
    _videoUrlCtrl.dispose();
    _marketTitleCtrl.dispose();
    _marketPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() => _imageXFile = x);
  }

  Future<Map<String, dynamic>?> _loadProfileLocation(
    SupabaseClient supabase,
  ) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final profile = await supabase
        .from('profiles')
        .select('city, latitude, longitude')
        .eq('id', user.id)
        .maybeSingle();

    return profile;
  }

  bool _isValidYoutubeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') || host.contains('youtu.be');
  }

  bool get _showMarketTemplate => _selectedPostType == PostType.market;

  String _buildMarketTemplateContent(String freeTextDescription) {
    final title = _marketTitleCtrl.text.trim();
    final price = _marketPriceCtrl.text.trim();
    final intentLabel = _selectedMarketIntent == 'buying' ? 'BUYING' : 'SELLING';

    final lines = <String>[
      '[$intentLabel] $title',
      'Price: $price',
      if (freeTextDescription.isNotEmpty) 'Details: $freeTextDescription',
    ];

    return lines.join('\n');
  }

  Future<void> _submit() async {
    final typedContent = _contentCtrl.text.trim();

    if (_showMarketTemplate) {
      if (_marketTitleCtrl.text.trim().isEmpty ||
          _marketPriceCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add product title and price')),
        );
        return;
      }

      if (_imageXFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a product photo')),
        );
        return;
      }
    } else if (typedContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something')),
      );
      return;
    }

    final content = _showMarketTemplate
        ? _buildMarketTemplateContent(typedContent)
        : typedContent;

    final videoUrlRaw = _videoUrlCtrl.text.trim();
    final videoUrl = videoUrlRaw.isEmpty ? null : videoUrlRaw;

    if (_selectedPostType == PostType.market && _selectedMarketCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a market category')),
      );
      return;
    }

    // optional: validate youtube link if provided
    if (videoUrl != null && !_isValidYoutubeUrl(videoUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please paste a valid YouTube link (youtube.com / youtu.be)'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      final service = PostService(supabase);

      final profile = await _loadProfileLocation(supabase);
      final city = profile?['city'] as String?;
      final lat = profile?['latitude'] as num?;
      final lng = profile?['longitude'] as num?;

      final hasLocation = lat != null && lng != null;
      if (!hasLocation) {
        if (!mounted) return;

        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Location required'),
            content: const Text(
              'To post in the local feed, please set your location in your profile.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/complete-profile');
                },
                child: const Text('Complete Profile'),
              ),
            ],
          ),
        );

        return;
      }

      String? imageUrl;
      if (_imageXFile != null) {
        imageUrl = await service.uploadPostImage(
          image: _imageXFile!,
          userId: supabase.auth.currentUser!.id,
        );
      }

      await service.createPost(
        content: content,
        visibility: _visibility,
        latitude: lat.toDouble(),
        longitude: lng.toDouble(),
        locationName: city,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        postType: _selectedPostType.dbValue,
        marketCategory: _selectedPostType == PostType.market
            ? _selectedMarketCategory
            : null,
        marketIntent: _selectedPostType == PostType.market
            ? _selectedMarketIntent
            : null,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            DropdownButtonFormField<PostType>(
              initialValue: _selectedPostType,
              items: PostType.values.map((t) {
                return DropdownMenuItem(
                  value: t,
                  child: Text(t.label),
                );
              }).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedPostType = v ?? PostType.post;
                  if (_selectedPostType != PostType.market) {
                    _selectedMarketCategory = marketMainCategories.first;
                    _selectedMarketIntent = 'selling';
                  }
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Post category',
              ),
            ),
            const SizedBox(height: 12),

            if (_selectedPostType == PostType.market) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedMarketIntent,
                items: const [
                  DropdownMenuItem(value: 'selling', child: Text('Selling')),
                  DropdownMenuItem(value: 'buying', child: Text('Buying')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedMarketIntent = v);
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Marketplace type',
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _selectedMarketCategory,
                items: marketMainCategories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(marketCategoryLabel(c)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedMarketCategory = v);
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Product category',
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_showMarketTemplate) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: const Text(
                  'Market template: include product photo, title, and price.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _marketTitleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Product title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _marketPriceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Price',
                  hintText: 'Example: 49.99',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _contentCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: _showMarketTemplate ? 'Description (optional)' : 'What\'s on your mind?',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _videoUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'YouTube video URL (optional)',
                hintText: 'https://youtube.com/watch?v=...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _visibility,
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Public')),
                DropdownMenuItem(value: 'local', child: Text('Local')),
              ],
              onChanged: (v) => setState(() => _visibility = v ?? 'public'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Visibility',
              ),
            ),
            const SizedBox(height: 12),

            if (_imageXFile != null) ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: FileImage(_imageXFile!.path as dynamic),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text('Add Photo'),
            ),
            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }
}