import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_locale.dart';
import '../../services/api_client.dart';
import '../../services/admin_service.dart';

class AdminCatalog extends StatefulWidget {
  const AdminCatalog({super.key});

  @override
  State<AdminCatalog> createState() => _AdminCatalogState();
}

class _AdminCatalogState extends State<AdminCatalog> {
  String _filter = 'all'; // all, women, men
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();

  // API data
  List<Map<String, dynamic>> _apiStyles = [];
  Map<String, dynamic> _catalogStats = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  List<Map<String, dynamic>> _extractStyles(Map<String, dynamic> response) {
    final raw = response['items'] ?? response['styles'] ?? response['data'] ?? response;
    final list = raw is List
        ? raw
        : (raw is Map ? (raw['items'] ?? raw['styles'] ?? []) : []);
    return list is List ? List<Map<String, dynamic>>.from(list) : <Map<String, dynamic>>[];
  }

  bool _computeHasMore(Map<String, dynamic> response, int pageJustLoaded, int loadedSoFar, int batchSize) {
    final totalPages = response['totalPages'];
    if (totalPages is int) return pageJustLoaded < totalPages;
    final total = response['total'];
    if (total is int) return loadedSoFar < total;
    return batchSize >= _pageSize;
  }

  Map<String, String> _buildQuery(int page) {
    final q = <String, String>{
      'page': '$page',
      'limit': '$_pageSize',
    };
    if (_filter != 'all') q['gender'] = _filter;
    return q;
  }

  Future<void> _fetchData() async {
    debugPrint('[Catalog] _fetchData() started — filter: $_filter');
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      final results = await Future.wait([
        AdminService.instance.getCatalogStyles(query: _buildQuery(1)),
        AdminService.instance.getCatalogStats(),
      ]);

      final stylesResponse = results[0];
      final statsResponse = results[1];

      final fetched = _extractStyles(stylesResponse);
      final hasMore = _computeHasMore(stylesResponse, 1, fetched.length, fetched.length);

      final statsRaw = statsResponse['data'] ?? statsResponse;
      final stats = statsRaw is Map<String, dynamic> ? statsRaw : <String, dynamic>{};

      setState(() {
        _apiStyles = fetched;
        _catalogStats = stats;
        _isLoading = false;
        _hasMore = hasMore;
        _page = 1;
      });
      debugPrint('[Catalog] page 1 — items=${fetched.length}, hasMore=$hasMore');
    } catch (e, stackTrace) {
      debugPrint('[Catalog] FETCH ERROR: $e\n$stackTrace');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore || _error != null) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    try {
      final response = await AdminService.instance.getCatalogStyles(query: _buildQuery(nextPage));
      final newItems = _extractStyles(response);
      final loadedSoFar = _apiStyles.length + newItems.length;
      final hasMore = newItems.isEmpty
          ? false
          : _computeHasMore(response, nextPage, loadedSoFar, newItems.length);

      setState(() {
        _apiStyles = [..._apiStyles, ...newItems];
        _page = nextPage;
        _hasMore = hasMore;
        _isLoadingMore = false;
      });
      debugPrint('[Catalog] page $nextPage — added=${newItems.length}, total=${_apiStyles.length}, hasMore=$hasMore');
    } catch (e) {
      debugPrint('[Catalog] _loadMore failed: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _showCreateStyleDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateStyleSheet(
        onCreated: () => _fetchData(),
      ),
    );
  }

  Future<void> _deleteStyle(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getBgSecondary(ctx),
        title: Text(tr('deleteStyle'), style: TextStyle(color: AppTheme.getTextPrimary(ctx))),
        content: Text(tr('confirmDeleteStyle'), style: TextStyle(color: AppTheme.getTextSecondary(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel'), style: TextStyle(color: AppTheme.getTextSecondary(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('delete'), style: const TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AdminService.instance.deleteStyle(id);
        _fetchData();
      } catch (e) {
        debugPrint('Failed to delete style: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('errorDeletingStyle'))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Catalog] build() — isLoading: $_isLoading, apiStyles: ${_apiStyles.length}, filter: $_filter, error: $_error');
    final isTablet = MediaQuery.of(context).size.width >= 600;
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildHeader(),
        _buildStats(),
        _buildFilters(),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _buildErrorState()
        else ...[
          _buildGrid(),
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (!_hasMore && _apiStyles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  '— ${_apiStyles.length} ${tr('total').toLowerCase()} —',
                  style: TextStyle(fontSize: 11, color: AppTheme.getTextTertiary(context)),
                ),
              ),
            ),
        ],
        const SizedBox(height: 120),
      ],
    );

    if (isTablet) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: content,
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: content,
    );
  }

  Widget _buildHeader() {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('styleCatalog'),
                      style: AppTheme.displayFont.copyWith(
                        fontSize: 24,
                        color: AppTheme.getTextPrimary(context),
                      )),
                  Text(tr('manageCatalog'),
                      style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context))),
                ],
              ),
              GestureDetector(
                onTap: _showCreateStyleDialog,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.getGold(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStats() {
    final totalCount = '${_catalogStats['total'] ?? _catalogStats['totalStyles'] ?? 0}';
    final womenCount = '${_catalogStats['women'] ?? _catalogStats['womenCount'] ?? 0}';
    final menCount = '${_catalogStats['men'] ?? _catalogStats['menCount'] ?? 0}';
    final totalTryOns = '${_catalogStats['tryOns'] ?? _catalogStats['totalTryOns'] ?? 0}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          _miniStat(totalCount, tr('total')),
          const SizedBox(width: 8),
          _miniStat(womenCount, tr('women')),
          const SizedBox(width: 8),
          _miniStat(menCount, tr('men')),
          const SizedBox(width: 8),
          _miniStat(totalTryOns, tr('tryOns')),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Expanded(
      child: Builder(
        builder: (context) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.getBgSecondary(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: Column(
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.getTextPrimary(context))),
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.getTextSecondary(context))),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    final filters = [
      ('all', tr('all')),
      ('women', tr('women')),
      ('men', tr('men')),
    ];
    return SizedBox(
      height: 48,
      child: Builder(
        builder: (context) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            scrollDirection: Axis.horizontal,
            children: filters.map((f) {
              final isSelected = _filter == f.$1;
              return GestureDetector(
                onTap: () {
                  setState(() => _filter = f.$1);
                  _fetchData();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.getGold(context) : AppTheme.getBgSecondary(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppTheme.getGold(context) : AppTheme.getBorder(context),
                    ),
                  ),
                  child: Text(f.$2,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : AppTheme.getTextSecondary(context))),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildGrid() {
    debugPrint('[Catalog] Building grid — apiStyles: ${_apiStyles.length}, isLoading: $_isLoading');
    if (_apiStyles.isEmpty) {
      debugPrint('[Catalog] _apiStyles is EMPTY — showing empty state');
      return _buildEmptyState();
    }
    debugPrint('[Catalog] _apiStyles has ${_apiStyles.length} items — showing grid');
    return _buildApiGrid();
  }

  Widget _buildEmptyState() {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.style_outlined, size: 48, color: AppTheme.getTextTertiary(context)),
                const SizedBox(height: 12),
                Text(
                  tr('noStylesYet'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.getTextSecondary(context)),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _showCreateStyleDialog,
                  child: Text(
                    'Tap + to add one.',
                    style: TextStyle(fontSize: 13, color: AppTheme.getGold(context)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.cloud_off, size: 48, color: AppTheme.accentRed),
                const SizedBox(height: 12),
                Text(
                  tr('errorLoadingCatalog'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.getTextSecondary(context)),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _fetchData,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.getBgSecondary(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.getBorder(context)),
                    ),
                    child: Text(
                      tr('retry'),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.getGold(context)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildApiGrid() {
    final styles = _apiStyles;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.65,
        ),
        itemCount: styles.length,
        itemBuilder: (context, index) {
          final style = styles[index];
          final id = '${style['id'] ?? style['_id'] ?? ''}';
          final name = style['name'] ?? '';
          final price = '${style['price'] ?? 0}';
          final gender = '${style['gender'] ?? 'women'}';
          final category = '${style['category'] ?? ''}';
          final subcategory = style['subcategory']?.toString();
          final imageUrl = ApiClient.getImageUrl(style['imageUrl']?.toString() ?? style['image']?.toString());
          final tryOns = style['tryOns'] ?? 0;
          final isFeatured = style['isFeatured'] == true;
          final priceMax = style['priceMax'];
          final priceDisplay = (priceMax != null && priceMax != style['price'])
              ? '$price - $priceMax ${tr("fcfa")}'
              : '$price ${tr("fcfa")}';
          final badgeColor = switch (gender) {
            'women' => const Color(0xFFE091B0),
            'men' => AppTheme.accentBlue,
            'unisex' => const Color(0xFFAB68FF),
            _ => AppTheme.accentBlue,
          };
          final genderLabel = switch (gender) {
            'women' => tr('women'),
            'men' => tr('men'),
            'unisex' => tr('unisex'),
            _ => gender,
          };

          return Container(
            decoration: BoxDecoration(
              color: AppTheme.getBgSecondary(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl.toString().isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppTheme.getBgSecondary(context),
                                child: Icon(Icons.image_not_supported, color: AppTheme.getTextTertiary(context)),
                              ),
                            )
                          : Container(
                              color: AppTheme.getBgSecondary(context),
                              child: Icon(Icons.image, color: AppTheme.getTextTertiary(context)),
                            ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            genderLabel,
                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                      if (isFeatured)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.star_rounded, size: 14, color: AppTheme.getGold(context)),
                          ),
                        ),
                      if (tryOns is int && tryOns > 0 && !isFeatured)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.remove_red_eye, size: 10, color: AppTheme.getGold(context)),
                                const SizedBox(width: 3),
                                Text('$tryOns', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.getGold(context))),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                            subcategory != null && subcategory.isNotEmpty
                                ? '$category / $subcategory'
                                : category,
                            style: TextStyle(fontSize: 10, color: AppTheme.getTextSecondary(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(priceDisplay,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.getGold(context)),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (id.isNotEmpty)
                              GestureDetector(
                                onTap: () => _deleteStyle(id),
                                child: Icon(Icons.delete_outline, size: 16, color: AppTheme.accentRed),
                              )
                            else
                              Icon(Icons.more_horiz, size: 16, color: AppTheme.getTextTertiary(context)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}

// ═══════════════════════════════════════════════════════
//  Full-screen Create Style Bottom Sheet
// ═══════════════════════════════════════════════════════

class _CreateStyleSheet extends StatefulWidget {
  final VoidCallback onCreated;

  const _CreateStyleSheet({required this.onCreated});

  @override
  State<_CreateStyleSheet> createState() => _CreateStyleSheetState();
}

class _CreateStyleSheetState extends State<_CreateStyleSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  final _subcategoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _priceMaxController = TextEditingController();
  bool _isFeatured = false;
  bool _isActive = true;

  XFile? _imageFile;
  Uint8List? _imageBytes;
  String _selectedGender = 'women';
  String _selectedCategory = 'braids';
  bool _isSaving = false;

  static const _categories = ['wigs', 'braids', 'locs', 'curls', 'fades', 'twists', 'weaves', 'natural', 'cornrows', 'updos', 'color'];
  static const _categoryIcons = {
    'wigs': Icons.face_retouching_natural,
    'braids': Icons.auto_awesome,
    'locs': Icons.waves,
    'curls': Icons.bubble_chart,
    'fades': Icons.content_cut,
    'twists': Icons.cyclone,
    'weaves': Icons.layers,
    'natural': Icons.eco,
    'cornrows': Icons.view_day,
    'updos': Icons.vertical_align_top,
    'color': Icons.palette,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _subcategoryController.dispose();
    _tagsController.dispose();
    _priceMaxController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageFile = picked;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getBgSecondary(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: AppTheme.getGold(ctx)),
                title: Text(tr('gallery'), style: TextStyle(color: AppTheme.getTextPrimary(ctx))),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: AppTheme.getGold(ctx)),
                title: Text(tr('camera'), style: TextStyle(color: AppTheme.getTextPrimary(ctx))),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    // Validation
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('imageRequired')), backgroundColor: AppTheme.accentRed),
      );
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('nameRequired')), backgroundColor: AppTheme.accentRed),
      );
      return;
    }
    if (_priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('priceRequired')), backgroundColor: AppTheme.accentRed),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      // Generate nameKey from name: "Boho Braids Long" → "boho_braids_long"
      final nameKey = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
      final fields = <String, String>{
        'name': name,
        'nameKey': nameKey,
        'price': _priceController.text.trim(),
        'gender': _selectedGender,
        'category': _selectedCategory,
      };
      if (_descriptionController.text.trim().isNotEmpty) {
        fields['description'] = _descriptionController.text.trim();
      }
      if (_subcategoryController.text.trim().isNotEmpty) {
        fields['subcategory'] = _subcategoryController.text.trim();
      }
      if (_tagsController.text.trim().isNotEmpty) {
        fields['tags'] = _tagsController.text.trim(); // comma-separated string
      }
      if (_priceMaxController.text.trim().isNotEmpty) {
        fields['priceMax'] = _priceMaxController.text.trim();
      }
      fields['isFeatured'] = _isFeatured.toString();
      fields['isActive'] = _isActive.toString();

      await AdminService.instance.createStyleWithImage(
        imageFile: _imageFile!,
        fields: fields,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('styleCreated')),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        widget.onCreated();
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Failed to create style: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('styleCreateError')),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.getBgPrimary(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Drag Handle ──
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.getTextTertiary(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('createNewStyle'),
                      style: AppTheme.displayFont.copyWith(
                        fontSize: 22,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.getBgSecondary(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.getBorder(context)),
                        ),
                        child: Icon(Icons.close, size: 18, color: AppTheme.getTextSecondary(context)),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable content ──
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 20),
                  children: [
                    // ── Image Picker Area ──
                    GestureDetector(
                      onTap: _showImageSourcePicker,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.getBgSecondary(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _imageFile != null
                                ? AppTheme.getGold(context).withValues(alpha: 0.4)
                                : AppTheme.getBorder(context),
                            width: _imageFile != null ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _imageFile != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(_imageBytes!, fit: BoxFit.cover),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              )
                            : CustomPaint(
                                painter: _DashedBorderPainter(
                                  color: AppTheme.getTextTertiary(context),
                                  borderRadius: 16,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppTheme.getGoldDim(context),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.camera_alt_outlined, size: 32, color: AppTheme.getGold(context)),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        tr('tapToAddImage'),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.getTextSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Style Name ──
                    _buildLabel(tr('styleNameLabel')),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'e.g. Boho Braids',
                    ),

                    const SizedBox(height: 20),

                    // ── Price ──
                    _buildLabel(tr('priceLabel')),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _priceController,
                      hint: 'e.g. 15000',
                      keyboardType: TextInputType.number,
                      prefix: Text(
                        'FCFA  ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getGold(context),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Gender Segmented Control ──
                    _buildLabel(tr('gender')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildGenderButton('women', tr('women'), Icons.female),
                        const SizedBox(width: 12),
                        _buildGenderButton('men', tr('men'), Icons.male),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Category Chips ──
                    _buildLabel(tr('category')),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final cat = _categories[i];
                          final isSelected = _selectedCategory == cat;
                          final catKey = 'cat${cat[0].toUpperCase()}${cat.substring(1)}';
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.getGoldDim(ctx)
                                    : AppTheme.getBgGlass(ctx),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.getGold(ctx).withValues(alpha: 0.5)
                                      : AppTheme.getBorder(ctx),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _categoryIcons[cat] ?? Icons.style,
                                    size: 16,
                                    color: isSelected
                                        ? AppTheme.getGold(ctx)
                                        : AppTheme.getTextTertiary(ctx),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    tr(catKey),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? AppTheme.getGold(ctx)
                                          : AppTheme.getTextSecondary(ctx),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Description (optional) ──
                    _buildLabel('${tr('descriptionLabel')} (${tr('optional')})'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _descriptionController,
                      hint: '...',
                      maxLines: 3,
                    ),

                    const SizedBox(height: 20),
                    _buildLabel('${tr("subcategory")} (${tr("optional")})'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _subcategoryController,
                      hint: 'e.g. knotless, goddess',
                    ),

                    const SizedBox(height: 20),
                    _buildLabel('${tr("tags")} (${tr("optional")})'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _tagsController,
                      hint: 'protective, wedding, casual',
                    ),

                    const SizedBox(height: 20),
                    _buildLabel('${tr("priceRange")} max (${tr("optional")})'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _priceMaxController,
                      hint: 'e.g. 8000',
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(tr('featured'), style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500,
                                color: AppTheme.getTextPrimary(context),
                              )),
                              const Spacer(),
                              Switch(
                                value: _isFeatured,
                                activeColor: AppTheme.getGold(context),
                                onChanged: (v) => setState(() => _isFeatured = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Row(
                            children: [
                              Text(tr('active'), style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500,
                                color: AppTheme.getTextPrimary(context),
                              )),
                              const Spacer(),
                              Switch(
                                value: _isActive,
                                activeColor: AppTheme.accentGreen,
                                onChanged: (v) => setState(() => _isActive = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── Create Button ──
                    GestureDetector(
                      onTap: _isSaving ? null : _handleSave,
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          color: _isSaving
                              ? AppTheme.getTextTertiary(context)
                              : AppTheme.getGold(context),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: _isSaving
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.getBgPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      tr('creatingStyle'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.getBgPrimary(context),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  tr('createNewStyle'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.getBgPrimary(context),
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.getTextSecondary(context),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Widget? prefix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getBgSecondary(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 15,
          color: AppTheme.getTextPrimary(context),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.getTextTertiary(context)),
          prefixIcon: prefix != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 14, right: 0),
                  child: prefix,
                )
              : null,
          prefixIconConstraints: prefix != null
              ? const BoxConstraints(minWidth: 0, minHeight: 0)
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildGenderButton(String value, String label, IconData icon) {
    final isSelected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.getGoldDim(context)
                : AppTheme.getBgSecondary(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.getGold(context).withValues(alpha: 0.5)
                  : AppTheme.getBorder(context),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? AppTheme.getGold(context)
                    : AppTheme.getTextTertiary(context),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppTheme.getGold(context)
                      : AppTheme.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dashed border painter for the image placeholder ──
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  _DashedBorderPainter({
    required this.color,
    this.borderRadius = 16,
    this.dashWidth = 6,
    this.dashSpace = 4,
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        dashPath.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
